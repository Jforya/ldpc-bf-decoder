/*
 * tools/gen_vectors.c
 * 生成 RTL testbench 使用的输入向量、黄金输出和逐轮轨迹。
 *
 * 算法语义与 day5_bf_curve.c 一致:
 *   T=dv-1, 同步翻转, 无翻转提前失败, MAX_ITER=50。
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

    for(int n=0;n<N;n++) thresh[n]=col_deg[n]-1;
}

static void put_bits(FILE *f, const uint8_t *x)
{
    for(int n=N-1;n>=0;n--) fputc('0'+x[n],f);
    fputc('\n',f);
}

static int bf_decode(uint8_t *x, int *iters, FILE *trace, long fid)
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

        if(trace && fl){
            fprintf(trace,"F%ld I%d ",fid,it+1);
            put_bits(trace,x);
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

static void inject_unique(uint8_t *y, int count)
{
    int inj=0;
    while(inj<count){
        int p=(int)(rnd()%N);
        if(!y[p]){
            y[p]=1;
            inj++;
        }
    }
}

int main(int argc,char**argv)
{
    if(argc < 2){
        fprintf(stderr,"usage: %s <base_matrix.txt> [nframes]\n",argv[0]);
        return 1;
    }

    long nf=(argc>2)?atol(argv[2]):120;
    if(nf <= 0){
        fprintf(stderr,"nframes must be positive\n");
        return 1;
    }

    build_graph(argv[1]);
    rs=777ULL;

    FILE *fi=fopen("tv_in.txt","w");
    FILE *fo=fopen("tv_gold_bits.txt","w");
    FILE *ff=fopen("tv_gold_flags.txt","w");
    FILE *ft=fopen("trace_gold.txt","w");
    FILE *sum=fopen("tv_summary.csv","w");
    if(!fi || !fo || !ff || !ft || !sum){
        perror("open output");
        return 1;
    }

    fprintf(sum,"frame,injected_errors,success,iter_count,residual_errors\n");

    static uint8_t x[N], y[N];
    long ok_count=0, fail_count=0;
    for(long f=0; f<nf; f++){
        memset(y,0,sizeof y);
        int inj=0;

        if(f<5){
            inj=0;
        } else if(f<10){
            inject_unique(y,1);
            inj=1;
        } else if(f<20){
            inj=2+(int)(rnd()%19);
            inject_unique(y,inj);
        } else {
            static const double rl[6]={0.01,0.02,0.03,0.04,0.05,0.06};
            double rber=rl[f%6];
            for(int n=0;n<N;n++){
                if(rnd01()<rber){
                    y[n]=1;
                    inj++;
                }
            }
        }

        memcpy(x,y,sizeof x);
        int it;
        int ok=bf_decode(x,&it,ft,f);

        int residual=0;
        for(int n=0;n<N;n++) residual+=x[n];

        put_bits(fi,y);
        put_bits(fo,x);
        fputc('0'+ok,ff);
        for(int b=6;b>=0;b--) fputc('0'+((it>>b)&1),ff);
        fputc('\n',ff);

        fprintf(sum,"%ld,%d,%d,%d,%d\n",f,inj,ok,it,residual);
        if(ok) ok_count++; else fail_count++;
    }

    fclose(fi);
    fclose(fo);
    fclose(ff);
    fclose(ft);
    fclose(sum);

    fprintf(stderr,"vectors: %ld frames (%ld success, %ld fail)\n",nf,ok_count,fail_count);
    return 0;
}
