/* ============================================================================
 * MEX_ECG_FILTER  对拍用包装：把 C 滤波链暴露给 MATLAB 验证脚本
 * （PC 端验证工具，不属于单片机固件交付物；编译产物 *.mexw64 可随时删除）
 *
 * 用法（MATLAB 侧）：  y = mex_ecg_filter(csv_codes);
 * 编译：               mex -O mex_ecg_filter.c ../ecg_filter.c
 * ==========================================================================*/
#include "mex.h"
#include "../ecg_filter.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    const double *in;
    float        *out;
    mwSize        n, N;
    static ecg_filt_t g;   /* FIR 缓冲约 1.4 KB，放静态避免占栈 */

    (void)nlhs;
    if (nrhs != 1) {
        mexErrMsgIdAndTxt("ecg:args", "用法: y = mex_ecg_filter(csv_codes)");
    }

    in  = mxGetDoubles(prhs[0]);
    N   = (mwSize)mxGetNumberOfElements(prhs[0]);
    plhs[0] = mxCreateNumericMatrix(N, 1, mxSINGLE_CLASS, mxREAL);
    out = (float *)mxGetData(plhs[0]);

    ecg_filt_init(&g);
    for (n = 0; n < N; n++) {
        out[n] = ecg_filt_step(&g, (float)in[n]);
    }
}
