#include "zml_plugin.h"
#include "patch.hpp"
#include <Windows.h>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <map>
#include <stdexcept>
struct Route {ZmlLuaTransform fn;void* data;};
std::map<std::string,Route> routes;std::string output;int sinks{};
void check(bool c,const char* msg){if(!c)throw std::runtime_error(msg);}
void log(void*,const char*){}
int add(void*,const char* name,ZmlLuaTransform fn,void* data){check(routes.emplace(name,Route{fn,data}).second,"unique routes");return 1;}
void sink(void*,const char* p,size_t n){output.assign(p,n);++sinks;}
std::string read(const std::filesystem::path& p){std::ifstream f(p,std::ios::binary);check(bool(f),"read fixture");return {std::istreambuf_iterator<char>(f),{}};}
int main(int argc,char** argv){try{
    check(argc==4,"usage: dll client-lua output");
    auto path=std::filesystem::absolute(argv[1]);auto dll=LoadLibraryW(path.c_str());check(dll!=nullptr,"DLL loads");
    auto entry=reinterpret_cast<ZmlPluginEntry>(GetProcAddress(dll,"ZML_PluginV1"));check(entry!=nullptr,"ABI export");auto plugin=entry();
    check(plugin&&plugin->size==sizeof(ZmlPlugin)&&plugin->abi==1&&std::string_view(plugin->id)=="more-teams","manifest identity");
    auto dir=path.parent_path().u8string();ZmlHost h{sizeof(ZmlHost),1,nullptr,reinterpret_cast<const char*>(dir.c_str()),"C:/test-more-teams-state",log,add};
    check(!plugin->start(nullptr),"null host rejected");auto bad=h;bad.abi=2;check(!plugin->start(&bad),"ABI rejected");bad=h;bad.state_directory="";check(!plugin->start(&bad),"missing state rejected");
    check(plugin->start(&h)==1&&routes.size()==2,"native UI and phase transform routes");
    for(auto [module,relative]:{std::pair{"UI/Panels/CharFormation/CharFormationCtrl","ui/panels/charformation/charformationctrl.lua"},
                              std::pair{"Phase/CharFormation/PhaseCharFormation","phase/charformation/phasecharformation.lua"}}){
        auto source=read(std::filesystem::path(argv[2])/relative);auto route=routes.at(module);sinks=0;
        check(route.fn(route.data,source.data(),source.size(),sink,nullptr)==1&&sinks==1,"current client contract transforms once");
        check(output.find("__ZML_STATE_DIRECTORY__")==output.npos&&output.find("C:/test-more-teams-state")!=output.npos,"safe state literal injected");
        auto patched=output;auto dest=std::filesystem::path(argv[3]);std::filesystem::create_directories(dest);std::ofstream(dest/(route.data?"phase.lua":"ctrl.lua"),std::ios::binary)<<output;
        for(auto invalid:{patched,std::string("unexpected client"),source+source,source+std::string(1,'\0')}){
            sinks=0;output="sentinel";check(!route.fn(route.data,invalid.data(),invalid.size(),sink,nullptr)&&!sinks&&output=="sentinel","atomic idempotence and ambiguity/NUL failure");
        }
        auto broken=source;auto at=broken.find(route.data?"_TrySendSetSquad = ":"_WrapTeamIndex = ");check(at!=broken.npos,"fixture anchor");broken.replace(at,1,"X");sinks=0;
        check(!route.fn(route.data,broken.data(),broken.size(),sink,nullptr)&&!sinks,"partial contracts cannot publish");
        if(route.data){
            for(auto anchor:{std::string("    if not setSquad then"),std::string("string.format(\"0%d\", teamIndex)")}){
                broken=source;at=broken.find(anchor);check(at!=broken.npos,"local-return/scene fixture anchor");
                broken.replace(at,anchor.size(),"changed client anchor");sinks=0;output="sentinel";
                check(!route.fn(route.data,broken.data(),broken.size(),sink,nullptr)&&!sinks&&output=="sentinel","new anchors fail atomically");
            }
        }
        check(!route.fn(route.data,nullptr,0,sink,nullptr),"null source rejected");
    }
    FreeLibrary(dll);std::cout<<"PASS actual DLL ABI, current source contracts, atomic failure and safe path injection\n";return 0;
}catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}}
