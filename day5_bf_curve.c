/*
 * day5_bf_curve.c
 * Day5: QC-LDPC 多比特 BF 正式性能曲线仿真
 *
 * 输出:
 *   day5_fer_curve.csv
 *
 * 说明:
 *   本文件独立放在项目根目录，不修改 ldpc_bf_project 文件夹。
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#define MB 40
#define NB 50
#define Z  40
#define M  (MB*Z)
#define N  (NB*Z)
#define K  (N-M)
#define MAX_ITER 50

static int row_deg[M], row_nbr[M][8];
static int col_deg[N], col_nbr[N][8];
static int thresh[N];

static uint64_t rs;
static inline uint64_t rnd(void){ rs^=rs<<13; rs^=rs>>7; rs^=rs<<17; return rs; }
static inline double rnd01(void){ return (rnd()>>11) * (1.0/9007199254740992.0); }

static void build_graph(const char *path)
{
    FILE *f = fopen(path, "r");
    if(!f){ perror("base"); exit(1); }

    int B[MB][NB];
    for(int i=0;i<MB;i++){
        for(int j=0;j<NB;j++){
            if(fscanf(f,"%d",&B[i][j])!=1){
                fprintf(stderr,"parse err\n");
                exit(1);
            }
        }
    }
    fclose(f);

    for(int bi=0;bi<MB;bi++){
        for(int bj=0;bj<NB;bj++){
            int s=B[bi][bj];
            if(s<0) continue;

            for(int r=0;r<Z;r++){
                int m=bi*Z+r;
                int n=bj*Z+(r+s)%Z;
                row_nbr[m][row_deg[m]++]=n;
                col_nbr[n][col_deg[n]++]=m;
            }
        }
    }

    for(int n=0;n<N;n++){
        thresh[n]=col_deg[n]-1;
    }
}

static int bf_decode(uint8_t *x, int *iters)
{
    static uint8_t s[M];
    static int conflict[N];

    for(int it=0; it<MAX_ITER; it++){
        int w=0;

        for(int m=0;m<M;m++){
            uint8_t p=0;
            for(int k=0;k<row_deg[m];k++) p^=x[row_nbr[m][k]];
            s[m]=p;
            w+=p;
        }

        if(!w){
            *iters=it;
            return 1;
        }

        for(int n=0;n<N;n++){
            int c=0;
            for(int k=0;k<col_deg[n];k++) c+=s[col_nbr[n][k]];
            conflict[n]=c;
        }

        int fl=0;
        for(int n=0;n<N;n++){
            if(conflict[n]>=thresh[n]){
                x[n]^=1;
                fl++;
            }
        }

        if(!fl){
            *iters=it+1;
            return 0;
        }
    }

    for(int m=0;m<M;m++){
        uint8_t p=0;
        for(int k=0;k<row_deg[m];k++) p^=x[row_nbr[m][k]];
        if(p){
            *iters=MAX_ITER;
            return 0;
        }
    }

    *iters=MAX_ITER;
    return 1;
}

int main(int argc,char**argv)
{
    const char *base_path = "附件/qc_peg_40_50_invc6dplopt_shift_inv.txt";
    if(argc > 1) base_path = argv[1];

    rs=(argc > 2) ? strtoull(argv[2],0,10) : 20260617ULL;
    build_graph(base_path);

    const double pts[]={0.005,0.01,0.02,0.03,0.04,0.05,0.06,0.08,0.10};
    FILE *csv=fopen("day5_fer_curve.csv","w");
    if(!csv){
        perror("day5_fer_curve.csv");
        return 1;
    }

    fprintf(csv,"rber,frames,frame_errors,fer,uber,avg_iter\n");
    printf("%8s %9s %7s %12s %12s %9s\n","RBER","frames","FE","FER","UBER","avg_iter");

    static uint8_t x[N];
    for(unsigned p=0;p<sizeof pts/sizeof*pts;p++){
        double rber=pts[p];
        long fe=0,fr=0,itsum=0;

        while(!((fe>=100 && fr>=2000) || fr>=300000)){
            for(int n=0;n<N;n++) x[n]=(rnd01()<rber);

            int it;
            int ok=bf_decode(x,&it);

            int residual=0;
            for(int n=0;n<N;n++) residual|=x[n];

            if(!ok || residual) fe++;
            itsum+=it;
            fr++;
        }

        double fer=(double)fe/fr;
        double uber=fer/K;
        double avg_iter=(double)itsum/fr;

        printf("%8.3f %9ld %7ld %12.4e %12.4e %9.2f\n",rber,fr,fe,fer,uber,avg_iter);
        fprintf(csv,"%.4f,%ld,%ld,%.6e,%.6e,%.3f\n",rber,fr,fe,fer,uber,avg_iter);
        fflush(csv);
    }

    fclose(csv);
    return 0;
}
