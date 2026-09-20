#define main AppMixerMain
#include "../Source/Mixer.mm"
#undef main
#include <cassert>
struct Buffers {UInt32 count;AudioBuffer b[3];};
int main(){@autoreleasepool{
 Engine e;float mic[4]={99,99,99,99};float samples[8]={.4,-.2,.8,-.6,2,-2,NAN,INFINITY},out[8]={};
 Buffers in{2,{{1,sizeof(mic),mic},{2,sizeof(samples),samples}}};Buffers dest{1,{{2,sizeof(out),out}}};
 e.gain.store(.5);e.smooth=.5;Engine::render(0,nullptr,(AudioBufferList*)&in,nullptr,(AudioBufferList*)&dest,nullptr,&e);
 assert(fabs(out[0]-.2)<1e-6 && fabs(out[1]+.1)<1e-6);assert(out[4]==1 && out[5]==-1);assert(out[6]==0&&out[7]==0);assert(e.callbacks.load()==1);
 float left[2]={.8,.4},right[2]={-.4,-.8},ol[2]={},orr[2]={};Buffers planar{3,{{1,sizeof(mic),mic},{1,sizeof(left),left},{1,sizeof(right),right}}};Buffers pout{2,{{1,sizeof(ol),ol},{1,sizeof(orr),orr}}};
 Engine::render(0,nullptr,(AudioBufferList*)&planar,nullptr,(AudioBufferList*)&pout,nullptr,&e);assert(fabs(ol[0]-.4)<1e-6 && fabs(orr[1]+.4)<1e-6);
 e.gain.store(0);e.smooth=0;Engine::render(0,nullptr,(AudioBufferList*)&planar,nullptr,(AudioBufferList*)&pout,nullptr,&e);assert(ol[0]==0&&orr[1]==0);
 e.smooth=1;e.gain.store(0);Engine::render(0,nullptr,(AudioBufferList*)&planar,nullptr,(AudioBufferList*)&pout,nullptr,&e);assert(ol[0]>.79&&ol[0]<.8);assert(e.smooth<1&&e.smooth>.98);
 Buffers empty{0,{}};std::fill(out,out+8,1);Engine::render(0,nullptr,(AudioBufferList*)&empty,nullptr,(AudioBufferList*)&dest,nullptr,&e);for(float x:out)assert(x==0);
 e.monitoring=true;e.peak.store(0);std::fill(out,out+8,1);Engine::render(0,nullptr,(AudioBufferList*)&in,nullptr,(AudioBufferList*)&dest,nullptr,&e);for(float x:out)assert(x==0);assert(e.peak.load()==2);e.monitoring=false;
 puts("PASS: stereo/planar, physical-input exclusion, gain, mute, smoothing, clipping, NaN/Inf, empty input");
}return 0;}
