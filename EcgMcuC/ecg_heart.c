/* ============================================================================
 * ECG_HEART  实现（逐点流式心率检测）
 * 算法说明与使用方式见 ecg_heart.h 头注释。
 * ==========================================================================*/

#include "ecg_heart.h"

/*********************************************************************************************************
*                                             内部函数声明
*********************************************************************************************************/
static void     SubmitBlock(ecg_heart_t *h);          /* 块提交: 刷新窗极值与信号有效性 */
static float    CalcThreshold(const ecg_heart_t *h);  /* 自适应门限 */
static void     PushRR(ecg_heart_t *h, uint16_t rr);  /* 记录 RR 并更新心率 */
static uint16_t MedianRR(const ecg_heart_t *h);       /* RR 环形缓冲中位数 */

/*********************************************************************************************************
* 函数名称：ecg_heart_init
* 功能功能：初始化心率检测器(清零全部状态)
*********************************************************************************************************/
void ecg_heart_init(ecg_heart_t *h)
{
    uint16_t i;

    h->blkPos     = 0;
    h->blkMax     = -1.0e9f;   /* 哨兵: 首块从最小开始累积 */
    h->blkMin     =  1.0e9f;
    h->blkPtr     = 0;
    h->blkValid   = 0;
    h->winMax     = 0.0f;
    h->winMin     = 0.0f;
    h->sigValid   = 0;

    h->peakActive = 0;
    h->peakVal    = 0.0f;
    h->peakPos    = 0;
    h->fallCnt    = 0;
    h->refractory = 0;

    h->sampleIdx   = 0;
    h->lastPeakIdx = 0;
    h->hasLastPeak = 0;
    h->rrCnt       = 0;
    h->rrPtr       = 0;
    h->medRR       = 0;
    h->peakCount   = 0;
    h->bpm         = 0;

    for(i = 0; i < ECG_HR_BLK_NUM; i++)
    {
        h->blkMaxArr[i] = 0.0f;
        h->blkMinArr[i] = 0.0f;
    }
    for(i = 0; i < ECG_HR_MAX_RR; i++)
    {
        h->rrArr[i] = 0;
    }
}

/*********************************************************************************************************
* 函数名称：SubmitBlock
* 功能功能：提交当前块极值, 刷新窗 max/min 与信号有效性判定
*********************************************************************************************************/
static void SubmitBlock(ecg_heart_t *h)
{
    uint8_t i, n;
    float   mn, mx;

    h->blkMaxArr[h->blkPtr] = h->blkMax;
    h->blkMinArr[h->blkPtr] = h->blkMin;
    h->blkPtr++;
    if(h->blkPtr >= ECG_HR_BLK_NUM)
    {
        h->blkPtr = 0;
    }
    if(h->blkValid < ECG_HR_BLK_NUM)
    {
        h->blkValid++;
    }

    h->blkPos = 0;
    h->blkMax = -1.0e9f;       /* 新块重新累积 */
    h->blkMin =  1.0e9f;

    /* 刷新窗极值 */
    n  = h->blkValid;
    mx = h->blkMaxArr[0];
    mn = h->blkMinArr[0];
    for(i = 1; i < n; i++)
    {
        if(h->blkMaxArr[i] > mx) { mx = h->blkMaxArr[i]; }
        if(h->blkMinArr[i] < mn) { mn = h->blkMinArr[i]; }
    }
    h->winMax = mx;
    h->winMin = mn;

    /* 信号有效性: 已积累半个窗以上, 且窗峰峰值达到 ECG_HR_ABS_MIN */
    if((h->blkValid >= (ECG_HR_BLK_NUM / 2u)) &&
       ((mx - mn) >= (float)ECG_HR_ABS_MIN))
    {
        h->sigValid = 1;
    }
    else
    {
        h->sigValid = 0;
    }
}

/*********************************************************************************************************
* 函数名称：CalcThreshold
* 功能功能：自适应门限 thr = min + alpha*(max-min)
*********************************************************************************************************/
static float CalcThreshold(const ecg_heart_t *h)
{
    return h->winMin + ECG_HR_THR_ALPHA * (h->winMax - h->winMin);
}

/*********************************************************************************************************
* 函数名称：MedianRR
* 功能功能：RR 环形缓冲取中位数(拷贝后插入排序, n<=8)
*********************************************************************************************************/
static uint16_t MedianRR(const ecg_heart_t *h)
{
    uint16_t tmp[ECG_HR_MAX_RR];
    uint8_t  i, j, n;
    uint16_t key;

    n = h->rrCnt;
    for(i = 0; i < n; i++)
    {
        tmp[i] = h->rrArr[i];   /* 环形指针不影响中位数(排序后无差异) */
    }

    for(i = 1; i < n; i++)      /* 插入排序 */
    {
        key = tmp[i];
        j   = i;
        while((j > 0) && (tmp[j - 1] > key))
        {
            tmp[j] = tmp[j - 1];
            j--;
        }
        tmp[j] = key;
    }

    if((n & 1u) != 0u)
    {
        return tmp[n / 2];
    }
    return (uint16_t)(((uint32_t)tmp[n / 2 - 1u] + (uint32_t)tmp[n / 2] + 1u) / 2u);
}

/*********************************************************************************************************
* 函数名称：PushRR
* 功能功能：记录一个 R-R 间期, 达到输出条件后更新心率
*********************************************************************************************************/
static void PushRR(ecg_heart_t *h, uint16_t rr)
{
    uint32_t bpm;
    uint16_t med;

    h->rrArr[h->rrPtr] = rr;
    h->rrPtr++;
    if(h->rrPtr >= ECG_HR_MAX_RR)
    {
        h->rrPtr = 0;
    }
    if(h->rrCnt < ECG_HR_MAX_RR)
    {
        h->rrCnt++;
    }

    if(h->rrCnt < ECG_HR_MIN_RR_OUT)
    {
        return;                 /* 样本太少, 暂不输出 */
    }

    med = MedianRR(h);
    h->medRR = med;
    if(med > 0u)
    {
        /* bpm = 60*Fs/medRR; 500Hz 下即 30000/medRR (四舍五入) */
        bpm = (60u * (uint32_t)ECG_FS + (uint32_t)(med / 2u)) / (uint32_t)med;
        if((bpm >= (uint32_t)ECG_HR_HR_MIN) && (bpm <= (uint32_t)ECG_HR_HR_MAX))
        {
            h->bpm = (int16_t)bpm;
        }
        else
        {
            h->bpm = 0;         /* 超出合法范围(如脱落后漂移), 判无效 */
        }
    }
}

/*********************************************************************************************************
* 函数名称：ecg_heart_step
* 功能功能：逐样本心率检测(500Hz 实时调用)
* 输入参数：x - 滤波后的样本值(单位与门限一致, 即 ADC 码值域)
* 返 回 值：当前心率(bpm); 0 = 无效(信号丢失/样本不足/超范围)
*********************************************************************************************************/
int16_t ecg_heart_step(ecg_heart_t *h, float x)
{
    uint32_t diff;

    h->sampleIdx++;

    /* ---- 1. 滑窗分块极值维护 ---- */
    if(x > h->blkMax) { h->blkMax = x; }
    if(x < h->blkMin) { h->blkMin = x; }
    h->blkPos++;
    if(h->blkPos >= (uint16_t)ECG_DET_BLK_LEN)
    {
        SubmitBlock(h);
    }

    /* ---- 2. 不应期倒计时(T波/噪声一律忽略) ---- */
    if(h->refractory > 0u)
    {
        h->refractory--;
        return h->bpm;
    }

    /* ---- 3. 信号丢失时清零历史, 防止旧 RR 污染 ---- */
    if(h->sigValid == 0u)
    {
        h->peakActive = 0;
        h->fallCnt    = 0;
        if(h->hasLastPeak != 0u)
        {
            h->hasLastPeak = 0;
            h->rrCnt       = 0;
            h->rrPtr       = 0;
            h->bpm         = 0;
        }
        return h->bpm;
    }

    /* ---- 4. 峰检测状态机 ---- */
    if(h->peakActive == 0u)
    {
        /* 等待过阈样本, 开始跟踪候选峰 */
        if(x > CalcThreshold(h))
        {
            h->peakActive = 1u;
            h->peakVal    = x;
            h->peakPos    = h->sampleIdx;
            h->fallCnt    = 0;
        }
        return h->bpm;
    }

    /* 跟踪中 */
    if(x >= h->peakVal)
    {
        h->peakVal = x;             /* 仍在攀升: 刷新峰值与位置 */
        h->peakPos = h->sampleIdx;
        h->fallCnt = 0;
        return h->bpm;
    }

    h->fallCnt++;
    if(h->fallCnt < (uint16_t)ECG_HR_CONFIRM_FALL)
    {
        return h->bpm;              /* 尚未确认(给信号一点回落时间) */
    }

    /* ---- 5. 确认一个 R 峰 ---- */
    /* 不应期从"峰位置"起算: 扣除本次确认已消耗的回落样本数,
     * 否则高频心率(如120bpm, RR=250)会被超长不应期周期性遮挡 */
    h->refractory = ((uint16_t)ECG_HR_REFRACTORY_SMP > h->fallCnt)
                    ? (uint16_t)((uint16_t)ECG_HR_REFRACTORY_SMP - h->fallCnt)
                    : 0u;
    h->peakActive = 0u;
    h->fallCnt    = 0u;
    h->peakCount++;

    if(h->hasLastPeak != 0u)
    {
        diff = h->peakPos - h->lastPeakIdx;
        if((diff >= (uint32_t)ECG_HR_REFRACTORY_SMP) && (diff <= ECG_HR_RR_MAX))
        {
            PushRR(h, (uint16_t)diff);
        }
    }
    h->lastPeakIdx = h->peakPos;
    h->hasLastPeak = 1u;

    return h->bpm;
}
