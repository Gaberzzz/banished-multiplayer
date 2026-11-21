// Wine / Proton detection. Banished has no Linux version: Linux players run the Windows game (and this DLL) through
// Proton or Wine. Wine's ntdll and kernel32 export a few functions Windows doesn't have; looking them up is the usual
// way to tell, and they give the Wine version and host system for the log and bug reports.
#include "common.h"

namespace wine {

static FARPROC Export(const wchar_t* dll, const char* name) {
    HMODULE m = GetModuleHandleW(dll);
    return m ? GetProcAddress(m, name) : nullptr;
}

const char* Version() {
    static const char* v = []() -> const char* {
        auto f = (const char*(CDECL*)())Export(L"ntdll.dll", "wine_get_version");
        return f ? f() : nullptr;
    }();
    return v;
}

std::string Describe() {
    if (!Version()) return "";
    std::string s = std::string("Wine ") + Version();
    if (auto build = (const char*(CDECL*)())Export(L"ntdll.dll", "wine_get_build_id"))
        if (const char* b = build()) s += std::string(" (build ") + b + ")";
    if (auto host = (void(CDECL*)(const char**, const char**))Export(L"ntdll.dll", "wine_get_host_version")) {
        const char *sys = nullptr, *rel = nullptr;
        host(&sys, &rel);
        if (sys) s += std::string(" on ") + sys + (rel ? std::string(" ") + rel : std::string());
    }
    return s;
}

std::string UnixPath(const std::wstring& win) {
    auto f = (char*(CDECL*)(const wchar_t*))Export(L"kernel32.dll", "wine_get_unix_file_name");
    char* p = f ? f(win.c_str()) : nullptr;  // allocated on the process heap
    if (!p) return "";
    std::string s = p;
    HeapFree(GetProcessHeap(), 0, p);
    return s;
}

}  // namespace wine
