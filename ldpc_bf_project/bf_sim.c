/*
 * bf_sim.c — QC-LDPC Multi-bit BF 译码器: 性能仿真 + RTL测试向量生成
 *
 * 模式1 (性能曲线):  ./bf_sim curve <base.txt> [seed]
 *   每个RBER点自适应仿真: 至少2000帧, 至少100个错误帧, 上限300000帧
 *   输出 fer_curve.csv
 *
 * 模式2 (测试向量):  ./bf_sim vectors <base.txt> <nframes> [seed]
 *   生成混合场景帧(无错/单错/多错/成功/失败/到达最大迭代)
 *   输出: tv_in.txt        每帧一行, 2000个'0'/'1', 左起=bit[N-1] (配合$readmemb)
 *         tv_gold_bits.txt 黄金译码输出, 同格式
 *         tv_gold_flags.txt 每帧一行8bit: {success, iter_count[6:0]}
 *         trace_gold.txt   逐轮轨迹: 每轮翻转后的x_hat, 行格式 "F<帧> I<轮> <2000bit>"
 *
 * 算法语义(黄金定义, RTL必须一致):
 *   阈值 T[j] = 列重dv[j]-1; 同步翻转; 无比特可翻提前失败; MAX_ITER=50
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
    FILE *f = fopen(path, "r"); if(!f){ perror("base"); exit(1); }
    int B[MB][NB];
    for(int i=0;i<MB;i++) for(int j=0;j<NB;j++)
        if(fscanf(f,"%d",&B[i][j])!=1){ fprintf(stderr,"parse err\n"); exit(1); }
    fclose(f);
    for(int bi=0;bi<MB;bi++) for(int bj=0;bj<NB;bj++){
        int s=B[bi][bj]; if(s<0) continue;
        for(int r=0;r<Z;r++){
            int m=bi*Z+r, n=bj*Z+(r+s)%Z;
            row_nbr[m][row_deg[m]++]=n;
            col_nbr[n][col_deg[n]++]=m;
        }
    }
    for(int n=0;n<N;n++) thresh[n]=col_deg[n]-1;
}

/* trace: 非NULL时把每轮翻转后的x写入 (帧号fid) */
static int bf_decode(uint8_t *x, int *iters, FILE *trace, long fid)
{
    static uint8_t s[M]; static int conflict[N];
    for(int it=0; it<MAX_ITER; it++){
        int w=0;
        for(int m=0;m<M;m++){
            uint8_t p=0;
            for(int k=0;k<row_deg[m];k++) p^=x[row_nbr[m][k]];
            s[m]=p; w+=p;
        }
        if(!w){ *iters=it; return 1; }
        for(int n=0;n<N;n++){
            int c=0;
            for(int k=0;k<col_deg[n];k++) c+=s[col_nbr[n][k]];
            conflict[n]=c;
        }
        int fl=0;
        for(int n=0;n<N;n++)
            if(conflict[n]>=thresh[n]){ x[n]^=1; fl++; }
        if(trace && fl){
            fprintf(trace,"F%ld I%d ",fid,it+1);
            for(int n=N-1;n>=0;n--) fputc('0'+x[n],trace);
            fputc('\n',trace);
        }
        if(!fl){ *iters=it+1; return 0; }
    }
    for(int m=0;m<M;m++){
        uint8_t p=0;
        for(int k=0;k<row_deg[m];k++) p^=x[row_nbr[m][k]];
        if(p){ *iters=MAX_ITER; return 0; }
    }
    *iters=MAX_ITER; return 1;
}

static void put_bits(FILE *f, const uint8_t *x)
{ for(int n=N-1;n>=0;n--) fputc('0'+x[n],f); fputc('\n',f); }

static void mode_curve(void)
{
    const double pts[]={0.005,0.01,0.02,0.03,0.04,0.05,0.06,0.08,0.10};
    FILE *csv=fopen("fer_curve.csv","w");
    fprintf(csv,"rber,frames,frame_errors,fer,uber,avg_iter\n");
    printf("%8s %9s %7s %12s %12s %9s\n","RBER","frames","FE","FER","UBER","avg_iter");
    static uint8_t x[N];
    for(unsigned p=0;p<sizeof pts/sizeof*pts;p++){
        double rber=pts[p]; long fe=0,fr=0,itsum=0;
        while(!((fe>=100&&fr>=2000)||fr>=300000)){
            for(int n=0;n<N;n++) x[n]=(rnd01()<rber);
            int it,ok=bf_decode(x,&it,NULL,0);
            int res=0; for(int n=0;n<N;n++) res|=x[n];
            if(!ok||res) fe++;
            itsum+=it; fr++;
        }
        double fer=(double)fe/fr;
        printf("%8.3f %9ld %7ld %12.4e %12.4e %9.2f\n",rber,fr,fe,fer,fer/K,(double)itsum/fr);
        fprintf(csv,"%.4f,%ld,%ld,%.6e,%.6e,%.3f\n",rber,fr,fe,fer,fer/K,(double)itsum/fr);
        fflush(csv);
    }
    fclose(csv);
}

static void mode_vectors(long nf)
{
    FILE *fi=fopen("tv_in.txt","w"), *fo=fopen("tv_gold_bits.txt","w");
    FILE *ff=fopen("tv_gold_flags.txt","w"), *ft=fopen("trace_gold.txt","w");
    FILE *sum=fopen("tv_summary.csv","w");
    fprintf(sum,"frame,injected_errors,success,iter_count\n");
    static uint8_t x[N], y[N];
    long n_ok=0,n_fail=0;
    for(long f=0; f<nf; f++){
        memset(y,0,sizeof y);
        int inj=0;
        if(f<5){ /* 无错误 */ }
        else if(f<10){ y[rnd()%N]^=1; inj=1; }                 /* 单比特错 */
        else if(f<20){ int e=2+(int)(rnd()%19);                /* 2~20个定数错 */
            for(int k=0;k<e;k++){ int p=rnd()%N; if(!y[p]){y[p]=1;inj++;} } }
        else {                                                  /* BSC混合RBER */
            static const double rl[6]={0.01,0.02,0.03,0.04,0.05,0.06};
            double rber=rl[f%6];
            for(int n=0;n<N;n++) if(rnd01()<rber){ y[n]=1; inj++; }
        }
        memcpy(x,y,sizeof x);
        int it,ok=bf_decode(x,&it,ft,f);
        put_bits(fi,y); put_bits(fo,x);
        fputc('0'+ok,ff);
        for(int b=6;b>=0;b--) fputc('0'+((it>>b)&1),ff);
        fputc('\n',ff);
        fprintf(sum,"%ld,%d,%d,%d\n",f,inj,ok,it);
        if(ok) n_ok++; else n_fail++;
    }
    fclose(fi);fclose(fo);fclose(ff);fclose(ft);fclose(sum);
    fprintf(stderr,"vectors: %ld frames (%ld success, %ld fail)\n",nf,n_ok,n_fail);
}

int main(int argc,char**argv)
{
    if(argc<3){ fprintf(stderr,"usage: %s curve|vectors base.txt [nframes] [seed]\n",argv[0]); return 1; }
    build_graph(argv[2]);
    if(!strcmp(argv[1],"curve")){
        rs=(argc>3)?strtoull(argv[3],0,10):20260612ULL;
        mode_curve();
    } else {
        long nf=(argc>3)?atol(argv[3]):120;
        rs=(argc>4)?strtoull(argv[4],0,10):777ULL;
        mode_vectors(nf);
    }
    return 0;
}
