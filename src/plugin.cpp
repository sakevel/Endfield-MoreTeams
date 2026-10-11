#include "zml_plugin.h"
#include "patch.hpp"
#include <filesystem>
#include <fstream>
#include <iterator>
#include <stdexcept>
namespace {
const ZmlHost* host{};std::string boot;
int transform(void* kind,const char* source,size_t size,ZmlSink sink,void* writer) noexcept{
    try{
        if(!source||!sink)return 0;
        std::string result;
        if(!teams::patch({source,size},kind!=nullptr,boot,result)){host->log(host->owner,"MoreTeams source contract rejected");return 0;}
        sink(writer,result.data(),result.size());return 1;
    }catch(...){return 0;}
}
int start(const ZmlHost* h) noexcept{
    try{
        if(!h||h->size!=sizeof(ZmlHost)||h->abi!=1||!h->mod_directory||!h->state_directory||!*h->state_directory||!h->log||!h->transform_lua)return 0;
        auto path=std::filesystem::path(std::u8string(reinterpret_cast<const char8_t*>(h->mod_directory)));
        auto read=[&](const wchar_t* name){
            auto p=path/name;auto size=std::filesystem::file_size(p);if(!size||size>64*1024)throw std::runtime_error("Invalid helper size");
            std::ifstream f(p,std::ios::binary);std::string s{std::istreambuf_iterator<char>(f),{}};
            if(s.size()!=size||s.find('\0')!=s.npos)throw std::runtime_error("Invalid helper");return s;
        };
        auto adapter=read(L"native.lua");size_t at;
        if(!teams::unique(adapter,"__ZML_STATE_DIRECTORY__",at))return 0;
        adapter.replace(at,23,teams::literal(h->state_directory));
        boot="do\nlocal ZMLMTFactory=(function()\n"+read(L"controller.lua")+"\nend)()\n"+adapter+"\n"+read(L"marks.lua")+"\n"+read(L"ui.lua")+"\nend\n";
        host=h;
        return h->transform_lua(h->owner,"UI/Panels/CharFormation/CharFormationCtrl",transform,nullptr)&&
            h->transform_lua(h->owner,"Phase/CharFormation/PhaseCharFormation",transform,reinterpret_cast<void*>(1));
    }catch(...){return 0;}
}
const ZmlPlugin plugin{sizeof(ZmlPlugin),1,"more-teams",start};
}
extern "C" __declspec(dllexport) const ZmlPlugin* ZML_PluginV1(){return &plugin;}
