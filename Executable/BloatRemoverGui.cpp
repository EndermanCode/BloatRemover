#include <windows.h>
#include <commctrl.h>
#include <shlwapi.h>
#include <shlobj.h>
#include <knownfolders.h>
#include <sddl.h>
#include <vector>
#include <string>
#include <sstream>
#include <algorithm>
#include <cstdio>
#include <cwctype>

#pragma comment(lib, "comctl32.lib")
#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(linker, "\"/manifestdependency:type='win32' name='Microsoft.Windows.Common-Controls' version='6.0.0.0' processorArchitecture='*' publicKeyToken='6595b64144ccf1df' language='*'\"")

struct AppItem {
    std::wstring id;
    std::wstring name;
    std::wstring type; // exe | msi | choco
    std::wstring path;
    std::wstring args;
    bool defaultSelected = false;
};

struct PowerSetting {
    bool enabled = false;
    int minutes = 0;
};

struct PowerConfig {
    bool disableFastStartup = true;
    PowerSetting hibernateAC;
    PowerSetting monitorAC;
    PowerSetting sleepAC;
    PowerSetting hibernateDC;
    PowerSetting monitorDC;
};

struct UserItem {
    std::wstring name;
    std::wstring groups;
};

struct BrowserItem {
    std::wstring id;
    std::wstring name;
    std::wstring path;
};

enum class MigrationKind {
    Folder,
    Thunderbird,
    Outlook,
    Programs
};

struct MigrationItem {
    std::wstring id;
    std::wstring name;
    std::wstring path;
    MigrationKind kind = MigrationKind::Folder;
};

enum class JoinType {
    Workgroup = 0,
    Domain = 1
};

struct JoinConfig {
    bool enabled = false;
    JoinType type = JoinType::Workgroup;
    std::wstring target;
    std::wstring hostname;
};

static HINSTANCE g_hInst = nullptr;
static HWND g_hWnd = nullptr;
static HWND g_hList = nullptr;
static HWND g_hLog = nullptr;
static HWND g_hCustomList = nullptr;
static HWND g_hLblCustomName = nullptr;
static HWND g_hLblCustomPath = nullptr;
static HWND g_hLblCustomArgs = nullptr;
static HWND g_hCustomName = nullptr;
static HWND g_hCustomPath = nullptr;
static HWND g_hCustomArgs = nullptr;
static HWND g_hBtnInstall = nullptr;
static HWND g_hBtnPreset = nullptr;
static HWND g_hBtnSelectAll = nullptr;
static HWND g_hBtnClear = nullptr;
static HWND g_hBtnBrowse = nullptr;
static HWND g_hBtnRunCustom = nullptr;
static HWND g_hBtnInstallAllCustom = nullptr;
static HWND g_hBtnRunAll = nullptr;
static HWND g_hBtnCustomAdd = nullptr;
static HWND g_hBtnCustomRemove = nullptr;
static HWND g_hUserList = nullptr;
static HWND g_hLblUserName = nullptr;
static HWND g_hLblUserGroups = nullptr;
static HWND g_hUserName = nullptr;
static HWND g_hUserGroups = nullptr;
static HWND g_hBtnUserAdd = nullptr;
static HWND g_hBtnUserRemove = nullptr;
static HWND g_hBtnUserCreate = nullptr;
static HWND g_hGroupUsers = nullptr;
static HWND g_hGroupJoin = nullptr;
static HWND g_hChkJoinEnable = nullptr;
static HWND g_hRadioWorkgroup = nullptr;
static HWND g_hRadioDomain = nullptr;
static HWND g_hLblJoinTarget = nullptr;
static HWND g_hLblJoinHostname = nullptr;
static HWND g_hJoinTarget = nullptr;
static HWND g_hJoinHostname = nullptr;
static HWND g_hBtnJoinNow = nullptr;
static HWND g_hGroupPower = nullptr;
static HWND g_hChkFastStartup = nullptr;
static HWND g_hChkHibernateAC = nullptr;
static HWND g_hEditHibernateAC = nullptr;
static HWND g_hChkMonitorAC = nullptr;
static HWND g_hEditMonitorAC = nullptr;
static HWND g_hChkSleepAC = nullptr;
static HWND g_hEditSleepAC = nullptr;
static HWND g_hChkHibernateDC = nullptr;
static HWND g_hEditHibernateDC = nullptr;
static HWND g_hChkMonitorDC = nullptr;
static HWND g_hEditMonitorDC = nullptr;
static HWND g_hBtnApplyPower = nullptr;
static HWND g_hTab = nullptr;
static HWND g_hPageInstall = nullptr;
static HWND g_hPageCustom = nullptr;
static HWND g_hPageMigration = nullptr;
static HWND g_hPageBrowser = nullptr;
static HWND g_hPageSystem = nullptr;
static HWND g_hPagePower = nullptr;
static HWND g_hPageConfig = nullptr;
static HWND g_hBrowserList = nullptr;
static HWND g_hLblBrowserPath = nullptr;
static HWND g_hBrowserPath = nullptr;
static HWND g_hBtnBrowserBrowse = nullptr;
static HWND g_hBtnBrowserBackup = nullptr;
static HWND g_hBtnBrowserRestore = nullptr;
static HWND g_hChkBrowserDpapi = nullptr;
static HWND g_hBtnBrowserSelectAll = nullptr;
static HWND g_hBtnBrowserClear = nullptr;
static HWND g_hBrowserInfo = nullptr;
static HWND g_hMigrationList = nullptr;
static HWND g_hLblMigrationPath = nullptr;
static HWND g_hMigrationPath = nullptr;
static HWND g_hBtnMigrationBrowse = nullptr;
static HWND g_hLblMigrationInstaller = nullptr;
static HWND g_hMigrationInstallerPath = nullptr;
static HWND g_hBtnMigrationInstallerBrowse = nullptr;
static HWND g_hBtnMigrationBackup = nullptr;
static HWND g_hBtnMigrationRestore = nullptr;
static HWND g_hBtnMigrationSelectAll = nullptr;
static HWND g_hBtnMigrationClear = nullptr;
static HWND g_hMigrationInfo = nullptr;
static HWND g_hConfigPath = nullptr;
static HWND g_hBtnConfigBrowse = nullptr;
static HWND g_hBtnConfigLoad = nullptr;
static HWND g_hBtnConfigSave = nullptr;
static HWND g_hConfigInfo = nullptr;
static HWND g_hLblConfigPath = nullptr;

static std::vector<AppItem> g_items;
static std::wstring g_presetName = L"Standard Office Setup";
static std::vector<std::wstring> g_presetIds;
static PowerConfig g_power;
struct CustomPreset {
    std::wstring name;
    std::wstring path;
    std::wstring args;
};
static std::vector<CustomPreset> g_customPresets;
static std::vector<UserItem> g_users;
static std::vector<BrowserItem> g_browsers;
static std::vector<MigrationItem> g_migrationItems;
static std::wstring g_iniPath;
static std::wstring g_browserBackupPath;
static std::wstring g_migrationBackupPath;
static std::wstring g_migrationInstallerPath;
static JoinConfig g_join;
static bool g_configLoaded = false;

static const wchar_t* kAppTitle = L"BloatRemover Installer";
static const wchar_t* kIniFile = L"config.ini";
static const wchar_t* kPageClass = L"BloatRemoverPage";
static const wchar_t* kJoinPromptClass = L"BloatRemoverJoinPrompt";

enum ControlId {
    ID_LIST = 1001,
    ID_CUSTOM_LIST,
    ID_USER_LIST,
    ID_BTN_INSTALL,
    ID_BTN_PRESET,
    ID_BTN_SELECT_ALL,
    ID_BTN_CLEAR,
    ID_LABEL_CUSTOM_NAME,
    ID_LABEL_CUSTOM_PATH,
    ID_LABEL_CUSTOM_ARGS,
    ID_EDIT_CUSTOM_NAME,
    ID_EDIT_CUSTOM_PATH,
    ID_EDIT_CUSTOM_ARGS,
    ID_BTN_BROWSE,
    ID_BTN_RUN_CUSTOM,
    ID_BTN_INSTALL_ALL_CUSTOM,
    ID_BTN_RUN_ALL,
    ID_BTN_CUSTOM_ADD,
    ID_BTN_CUSTOM_REMOVE,
    ID_LABEL_USER_NAME,
    ID_LABEL_USER_GROUPS,
    ID_EDIT_USER_NAME,
    ID_EDIT_USER_GROUPS,
    ID_BTN_USER_ADD,
    ID_BTN_USER_REMOVE,
    ID_BTN_USER_CREATE,
    ID_GROUP_JOIN,
    ID_CHK_JOIN_ENABLE,
    ID_RADIO_JOIN_WORKGROUP,
    ID_RADIO_JOIN_DOMAIN,
    ID_LABEL_JOIN_TARGET,
    ID_LABEL_JOIN_HOSTNAME,
    ID_EDIT_JOIN_TARGET,
    ID_EDIT_JOIN_HOSTNAME,
    ID_BTN_JOIN_NOW,
    ID_GROUP_POWER,
    ID_CHK_FAST_STARTUP,
    ID_CHK_HIBERNATE_AC,
    ID_EDIT_HIBERNATE_AC,
    ID_CHK_MONITOR_AC,
    ID_EDIT_MONITOR_AC,
    ID_CHK_SLEEP_AC,
    ID_EDIT_SLEEP_AC,
    ID_CHK_HIBERNATE_DC,
    ID_EDIT_HIBERNATE_DC,
    ID_CHK_MONITOR_DC,
    ID_EDIT_MONITOR_DC,
    ID_BTN_APPLY_POWER,
    ID_TAB,
    ID_LABEL_CONFIG_PATH,
    ID_EDIT_CONFIG_PATH,
    ID_BTN_CONFIG_BROWSE,
    ID_BTN_CONFIG_LOAD,
    ID_BTN_CONFIG_SAVE,
    ID_EDIT_LOG,
    ID_BROWSER_LIST,
    ID_LABEL_BROWSER_PATH,
    ID_EDIT_BROWSER_PATH,
    ID_BTN_BROWSER_BROWSE,
    ID_BTN_BROWSER_BACKUP,
    ID_BTN_BROWSER_RESTORE,
    ID_CHK_BROWSER_DPAPI,
    ID_BTN_BROWSER_SELECT_ALL,
    ID_BTN_BROWSER_CLEAR,
    ID_LABEL_BROWSER_INFO,
    ID_MIGRATION_LIST,
    ID_LABEL_MIGRATION_PATH,
    ID_EDIT_MIGRATION_PATH,
    ID_BTN_MIGRATION_BROWSE,
    ID_BTN_MIGRATION_BACKUP,
    ID_BTN_MIGRATION_RESTORE,
    ID_BTN_MIGRATION_SELECT_ALL,
    ID_BTN_MIGRATION_CLEAR,
    ID_LABEL_MIGRATION_INFO,
    ID_LABEL_MIGRATION_INSTALLER,
    ID_EDIT_MIGRATION_INSTALLER,
    ID_BTN_MIGRATION_INSTALLER_BROWSE,
};

static std::wstring Trim(const std::wstring& s) {
    const wchar_t* ws = L" \t\r\n";
    size_t start = s.find_first_not_of(ws);
    if (start == std::wstring::npos) return L"";
    size_t end = s.find_last_not_of(ws);
    return s.substr(start, end - start + 1);
}

static std::vector<std::wstring> SplitCsv(const std::wstring& s) {
    std::vector<std::wstring> out;
    std::wstringstream ss(s);
    std::wstring item;
    while (std::getline(ss, item, L',')) {
        item = Trim(item);
        if (!item.empty()) {
            std::transform(item.begin(), item.end(), item.begin(), ::towlower);
            out.push_back(item);
        }
    }
    return out;
}

static std::wstring GetIniString(const std::wstring& section, const std::wstring& key, const std::wstring& def, const std::wstring& path) {
    wchar_t buf[2048];
    DWORD len = GetPrivateProfileStringW(section.c_str(), key.c_str(), def.c_str(), buf, 2048, path.c_str());
    return std::wstring(buf, len);
}

static void AppendLog(const std::wstring& line);
static LRESULT CALLBACK PageWndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
static std::wstring GetEditText(HWND hEdit);
static void PopulateList();
static void SetChecked(HWND hWnd, bool checked);
static void SetEditInt(HWND hEdit, int value);
static bool IsChecked(HWND hWnd);
static int GetEditInt(HWND hEdit, int def);
static int ClampNonNegative(int value);
static std::wstring GetCurrentHostname();
static bool RunProcess(const std::wstring& exe, const std::wstring& args, DWORD& exitCode);
static void ApplyPowerTweaks();
static std::wstring GetFolderPath(int csidl);
static std::wstring GetKnownFolderPath(const KNOWNFOLDERID& id);
static std::wstring GetLocalAppData();
static std::wstring GetRoamingAppData();
static std::wstring GetCurrentUserSid();
static std::wstring PathJoin(const std::wstring& a, const std::wstring& b);
static bool EnsureDirExists(const std::wstring& path);
static bool DeleteDirectoryRecursive(const std::wstring& path);
static bool CopyDirectoryRecursive(const std::wstring& src, const std::wstring& dst, bool overwrite, int& copied, int& failed);
static void LoadBrowserItems();
static void InitBrowserListColumns();
static void PopulateBrowserList();
static void SelectAllBrowsers(bool checked);
static void DoBrowserBrowse();
static void BackupBrowsers();
static void RestoreBrowsers();
static void UpdateBrowserBackupStatus();
static bool BackupDpapiKeys(const std::wstring& backupRoot);
static bool RestoreDpapiKeys(const std::wstring& backupRoot);
static void LoadMigrationItems();
static void InitMigrationListColumns();
static void PopulateMigrationList();
static void SelectAllMigration(bool checked);
static void DoMigrationBrowse();
static void DoMigrationInstallerBrowse();
static void BackupMigration();
static void RestoreMigration();
static void UpdateMigrationBackupStatus();
static void ExportInstalledPrograms(const std::wstring& destDir);
static std::vector<std::wstring> SplitCsvLine(const std::wstring& line);
static std::wstring NormalizeKey(const std::wstring& s);
static void CollectInstallerFiles(const std::wstring& root, std::vector<std::wstring>& files);
static std::wstring FindBestInstallerMatch(const std::wstring& appName, const std::vector<std::wstring>& installers);
static bool RunSilentInstaller(const std::wstring& installerPath, const std::wstring& baseArgs, const std::wstring& label, std::wstring& error);
static bool IsProgramInstalled(const std::wstring& name);
static std::wstring FindExeInPath(const std::wstring& exe);
static bool IsWingetAvailable();
static bool RunWingetInstallByName(const std::wstring& name, std::wstring& error);

static int GetIniInt(const std::wstring& section, const std::wstring& key, int def, const std::wstring& path) {
    return static_cast<int>(GetPrivateProfileIntW(section.c_str(), key.c_str(), def, path.c_str()));
}

static bool GetIniBool(const std::wstring& section, const std::wstring& key, bool def, const std::wstring& path) {
    int d = def ? 1 : 0;
    int v = GetIniInt(section, key, d, path);
    return v != 0;
}

static std::vector<std::wstring> GetIniSections(const std::wstring& path) {
    std::vector<wchar_t> buf(8192, L'\0');
    DWORD len = GetPrivateProfileSectionNamesW(buf.data(), static_cast<DWORD>(buf.size()), path.c_str());
    while (len == buf.size() - 2) {
        buf.resize(buf.size() * 2, L'\0');
        len = GetPrivateProfileSectionNamesW(buf.data(), static_cast<DWORD>(buf.size()), path.c_str());
    }
    std::vector<std::wstring> sections;
    const wchar_t* p = buf.data();
    while (*p) {
        std::wstring s = p;
        sections.push_back(s);
        p += s.size() + 1;
    }
    return sections;
}

static std::wstring ToLower(const std::wstring& s) {
    std::wstring out = s;
    std::transform(out.begin(), out.end(), out.begin(), ::towlower);
    return out;
}

static std::wstring GetExeDir() {
    wchar_t buf[MAX_PATH] = L"";
    DWORD len = GetModuleFileNameW(nullptr, buf, MAX_PATH);
    if (len == 0 || len >= MAX_PATH) return L".";
    PathRemoveFileSpecW(buf);
    return buf;
}

static std::wstring GetFolderPath(int csidl) {
    wchar_t buf[MAX_PATH] = L"";
    if (SUCCEEDED(SHGetFolderPathW(nullptr, csidl, nullptr, SHGFP_TYPE_CURRENT, buf))) {
        return buf;
    }
    return L"";
}

static std::wstring GetKnownFolderPath(const KNOWNFOLDERID& id) {
    PWSTR path = nullptr;
    if (SUCCEEDED(SHGetKnownFolderPath(id, 0, nullptr, &path)) && path) {
        std::wstring out = path;
        CoTaskMemFree(path);
        return out;
    }
    if (path) {
        CoTaskMemFree(path);
    }
    return L"";
}

static std::wstring GetLocalAppData() {
    return GetFolderPath(CSIDL_LOCAL_APPDATA);
}

static std::wstring GetRoamingAppData() {
    return GetFolderPath(CSIDL_APPDATA);
}

static std::wstring GetCurrentUserSid() {
    HANDLE token = nullptr;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return L"";
    DWORD size = 0;
    GetTokenInformation(token, TokenUser, nullptr, 0, &size);
    if (size == 0) {
        CloseHandle(token);
        return L"";
    }
    std::vector<BYTE> buf(size);
    if (!GetTokenInformation(token, TokenUser, buf.data(), size, &size)) {
        CloseHandle(token);
        return L"";
    }
    auto user = reinterpret_cast<TOKEN_USER*>(buf.data());
    LPWSTR sidStr = nullptr;
    if (!ConvertSidToStringSidW(user->User.Sid, &sidStr)) {
        CloseHandle(token);
        return L"";
    }
    std::wstring sid = sidStr;
    LocalFree(sidStr);
    CloseHandle(token);
    return sid;
}

static std::wstring PathJoin(const std::wstring& a, const std::wstring& b) {
    wchar_t buf[MAX_PATH] = L"";
    if (PathCombineW(buf, a.c_str(), b.c_str())) {
        return buf;
    }
    return a + L"\\" + b;
}

static bool EnsureDirExists(const std::wstring& path) {
    if (path.empty()) return false;
    int res = SHCreateDirectoryExW(nullptr, path.c_str(), nullptr);
    return res == ERROR_SUCCESS || res == ERROR_ALREADY_EXISTS;
}

static bool DeleteDirectoryRecursive(const std::wstring& path) {
    if (path.empty()) return false;
    DWORD attrs = GetFileAttributesW(path.c_str());
    if (attrs == INVALID_FILE_ATTRIBUTES) return true;
    if ((attrs & FILE_ATTRIBUTE_DIRECTORY) == 0) {
        SetFileAttributesW(path.c_str(), FILE_ATTRIBUTE_NORMAL);
        return DeleteFileW(path.c_str()) != FALSE;
    }
    std::wstring pattern = PathJoin(path, L"*");
    WIN32_FIND_DATAW ffd{};
    HANDLE hFind = FindFirstFileW(pattern.c_str(), &ffd);
    if (hFind == INVALID_HANDLE_VALUE) return false;
    do {
        if (wcscmp(ffd.cFileName, L".") == 0 || wcscmp(ffd.cFileName, L"..") == 0) continue;
        std::wstring item = PathJoin(path, ffd.cFileName);
        if (ffd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            SetFileAttributesW(item.c_str(), FILE_ATTRIBUTE_NORMAL);
            DeleteDirectoryRecursive(item);
        } else {
            SetFileAttributesW(item.c_str(), FILE_ATTRIBUTE_NORMAL);
            DeleteFileW(item.c_str());
        }
    } while (FindNextFileW(hFind, &ffd));
    FindClose(hFind);
    SetFileAttributesW(path.c_str(), FILE_ATTRIBUTE_NORMAL);
    return RemoveDirectoryW(path.c_str()) != FALSE;
}

static bool CopyDirectoryRecursive(const std::wstring& src, const std::wstring& dst, bool overwrite, int& copied, int& failed) {
    if (src.empty() || dst.empty()) {
        failed++;
        return false;
    }
    DWORD attrs = GetFileAttributesW(src.c_str());
    if (attrs == INVALID_FILE_ATTRIBUTES || (attrs & FILE_ATTRIBUTE_DIRECTORY) == 0) {
        failed++;
        return false;
    }
    EnsureDirExists(dst);
    std::wstring pattern = PathJoin(src, L"*");
    WIN32_FIND_DATAW ffd{};
    HANDLE hFind = FindFirstFileW(pattern.c_str(), &ffd);
    if (hFind == INVALID_HANDLE_VALUE) {
        failed++;
        return false;
    }
    do {
        if (wcscmp(ffd.cFileName, L".") == 0 || wcscmp(ffd.cFileName, L"..") == 0) continue;
        std::wstring s = PathJoin(src, ffd.cFileName);
        std::wstring d = PathJoin(dst, ffd.cFileName);
        if (ffd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            CopyDirectoryRecursive(s, d, overwrite, copied, failed);
        } else {
            if (CopyFileW(s.c_str(), d.c_str(), overwrite ? FALSE : TRUE)) {
                copied++;
            } else {
                failed++;
            }
        }
    } while (FindNextFileW(hFind, &ffd));
    FindClose(hFind);
    return failed == 0;
}

static void LoadBrowserItems() {
    g_browsers.clear();
    std::wstring local = GetLocalAppData();
    std::wstring roaming = GetRoamingAppData();
    if (!local.empty()) {
        g_browsers.push_back({ L"chrome", L"Google Chrome", PathJoin(local, L"Google\\Chrome\\User Data") });
        g_browsers.push_back({ L"edge", L"Microsoft Edge", PathJoin(local, L"Microsoft\\Edge\\User Data") });
        g_browsers.push_back({ L"brave", L"Brave", PathJoin(local, L"BraveSoftware\\Brave-Browser\\User Data") });
        g_browsers.push_back({ L"chromium", L"Chromium", PathJoin(local, L"Chromium\\User Data") });
        g_browsers.push_back({ L"vivaldi", L"Vivaldi", PathJoin(local, L"Vivaldi\\User Data") });
    }
    if (!roaming.empty()) {
        g_browsers.push_back({ L"firefox", L"Mozilla Firefox", PathJoin(roaming, L"Mozilla\\Firefox") });
        g_browsers.push_back({ L"opera", L"Opera", PathJoin(roaming, L"Opera Software\\Opera Stable") });
        g_browsers.push_back({ L"operagx", L"Opera GX", PathJoin(roaming, L"Opera Software\\Opera GX Stable") });
    }
}

static void LoadMigrationItems() {
    g_migrationItems.clear();
    g_migrationItems.push_back({ L"desktop", L"Desktop", GetKnownFolderPath(FOLDERID_Desktop), MigrationKind::Folder });
    g_migrationItems.push_back({ L"documents", L"Dokumente", GetKnownFolderPath(FOLDERID_Documents), MigrationKind::Folder });
    g_migrationItems.push_back({ L"downloads", L"Downloads", GetKnownFolderPath(FOLDERID_Downloads), MigrationKind::Folder });
    g_migrationItems.push_back({ L"pictures", L"Bilder", GetKnownFolderPath(FOLDERID_Pictures), MigrationKind::Folder });
    g_migrationItems.push_back({ L"music", L"Musik", GetKnownFolderPath(FOLDERID_Music), MigrationKind::Folder });
    g_migrationItems.push_back({ L"videos", L"Videos", GetKnownFolderPath(FOLDERID_Videos), MigrationKind::Folder });
    g_migrationItems.push_back({ L"favorites", L"Favoriten", GetKnownFolderPath(FOLDERID_Favorites), MigrationKind::Folder });

    std::wstring roaming = GetRoamingAppData();
    g_migrationItems.push_back({ L"thunderbird", L"Thunderbird", roaming.empty() ? L"" : PathJoin(roaming, L"Thunderbird"), MigrationKind::Thunderbird });
    g_migrationItems.push_back({ L"outlook", L"Outlook (PST/OST)", L"Automatisch", MigrationKind::Outlook });
    g_migrationItems.push_back({ L"programs", L"Programmliste (Export)", L"Registry", MigrationKind::Programs });
}

static std::wstring GetCurrentHostname() {
    wchar_t name[256] = L"";
    DWORD size = 256;
    if (GetComputerNameW(name, &size)) {
        return std::wstring(name);
    }
    return L"";
}

static std::wstring GetChocoExePath() {
    wchar_t buf[MAX_PATH] = L"";
    if (SearchPathW(nullptr, L"choco.exe", nullptr, MAX_PATH, buf, nullptr) > 0) {
        return std::wstring(buf);
    }
    std::wstring fallback = L"C:\\ProgramData\\chocolatey\\bin\\choco.exe";
    if (PathFileExistsW(fallback.c_str())) {
        return fallback;
    }
    return L"";
}

static bool EnsureChocolateyInstalled() {
    if (!GetChocoExePath().empty()) return true;
    AppendLog(L"Chocolatey not found. Installing...");
    std::wstring cmd = L"-NoProfile -ExecutionPolicy Bypass -Command \"";
    cmd += L"Set-ExecutionPolicy Bypass -Scope Process -Force; ";
    cmd += L"[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; ";
    cmd += L"iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))\"";
    DWORD exitCode = 0;
    RunProcess(L"powershell.exe", cmd, exitCode);
    if (GetChocoExePath().empty()) {
        AppendLog(L"Chocolatey install failed.");
        return false;
    }
    AppendLog(L"Chocolatey installed.");
    return true;
}

static std::wstring NormalizeChocoArgs(const std::wstring& args) {
    std::wstring out = args;
    auto has = [&](const std::wstring& flag) {
        return out.find(flag) != std::wstring::npos;
    };
    if (!has(L"--no-progress")) out += L" --no-progress";
    if (!has(L"--limit-output")) out += L" --limit-output";
    if (!has(L"--yes") && !has(L" -y") && !has(L"-y ")) out += L" -y";
    return out;
}
static void LoadDefaultConfig() {
    g_items.clear();
    g_presetName = L"Standard Office Setup";
    g_presetIds = {
        L"chrome", L"adobereader", L"7zip", L"firefox",
        L"teamviewer", L"notepadpp", L"hpsa", L"office"
    };

    g_power.disableFastStartup = true;
    g_power.hibernateAC = { true, 0 };
    g_power.monitorAC = { true, 30 };
    g_power.sleepAC = { true, 0 };
    g_power.hibernateDC = { true, 0 };
    g_power.monitorDC = { true, 10 };

    g_join.enabled = false;
    g_join.type = JoinType::Workgroup;
    g_join.target.clear();
    g_join.hostname = GetCurrentHostname();

    g_items.push_back({L"chrome", L"Google Chrome", L"choco", L"choco", L"install googlechrome -y --ignore-checksum -f", true});
    g_items.push_back({L"adobereader", L"Adobe Reader", L"choco", L"choco", L"install adobereader -y --ignore-checksum -f", true});
    g_items.push_back({L"7zip", L"7-Zip", L"choco", L"choco", L"install 7zip -y --ignore-checksum -f", true});
    g_items.push_back({L"firefox", L"Mozilla Firefox", L"choco", L"choco", L"install firefox -y --ignore-checksum -f", true});
    g_items.push_back({L"teamviewer", L"TeamViewer Host", L"choco", L"choco", L"install teamviewer.host -y --ignore-checksum -f", true});
    g_items.push_back({L"notepadpp", L"Notepad++", L"choco", L"choco", L"install notepadplusplus -y --ignore-checksum -f", true});
    g_items.push_back({L"hpsa", L"HP Support Assistant", L"choco", L"choco", L"install hpsupportassistant -y --ignore-checksum -f", true});
    g_items.push_back({L"office", L"Microsoft 365 Business", L"choco", L"choco", L"install office365business -y --ignore-checksum -f --params \"/eula:TRUE\" --execution-timeout=0", true});
}

static bool LoadConfigFile(const std::wstring& path) {
    if (!PathFileExistsW(path.c_str())) return false;

    g_items.clear();
    g_presetName = GetIniString(L"Preset", L"Name", L"Standard Office Setup", path);
    g_presetIds = SplitCsv(GetIniString(L"Preset", L"Ids", L"", path));

    g_power.disableFastStartup = GetIniBool(L"Power", L"DisableFastStartup", true, path);
    g_power.hibernateAC.enabled = GetIniBool(L"Power", L"EnableHibernateAC", true, path);
    g_power.hibernateAC.minutes = GetIniInt(L"Power", L"HibernateACMinutes", 0, path);
    g_power.monitorAC.enabled = GetIniBool(L"Power", L"EnableMonitorAC", true, path);
    g_power.monitorAC.minutes = GetIniInt(L"Power", L"MonitorACMinutes", 30, path);
    g_power.sleepAC.enabled = GetIniBool(L"Power", L"EnableSleepAC", true, path);
    g_power.sleepAC.minutes = GetIniInt(L"Power", L"SleepACMinutes", 0, path);
    g_power.hibernateDC.enabled = GetIniBool(L"Power", L"EnableHibernateDC", true, path);
    g_power.hibernateDC.minutes = GetIniInt(L"Power", L"HibernateDCMinutes", 0, path);
    g_power.monitorDC.enabled = GetIniBool(L"Power", L"EnableMonitorDC", true, path);
    g_power.monitorDC.minutes = GetIniInt(L"Power", L"MonitorDCMinutes", 10, path);

    g_join.enabled = GetIniBool(L"Join", L"Enabled", false, path);
    std::wstring joinType = ToLower(GetIniString(L"Join", L"Type", L"workgroup", path));
    g_join.type = (joinType == L"domain") ? JoinType::Domain : JoinType::Workgroup;
    g_join.target = GetIniString(L"Join", L"Target", L"", path);
    g_join.hostname = GetIniString(L"Join", L"Hostname", L"", path);

    auto sections = GetIniSections(path);
    for (const auto& sec : sections) {
        if (sec.rfind(L"App.", 0) != 0) continue;
        std::wstring id = sec.substr(4);
        std::wstring name = GetIniString(sec, L"Name", id, path);
        std::wstring type = GetIniString(sec, L"Type", L"exe", path);
        std::wstring ipath = GetIniString(sec, L"Path", L"", path);
        std::wstring args = GetIniString(sec, L"Args", L"", path);
        std::wstring def = GetIniString(sec, L"Default", L"0", path);

        bool isDefault = (def == L"1" || def == L"true" || def == L"True");
        if (!g_presetIds.empty()) {
            std::wstring idLower = id;
            std::transform(idLower.begin(), idLower.end(), idLower.begin(), ::towlower);
            if (std::find(g_presetIds.begin(), g_presetIds.end(), idLower) != g_presetIds.end()) {
                isDefault = true;
            }
        }

        AppItem item;
        item.id = id;
        item.name = name;
        item.type = type;
        item.path = ipath;
        item.args = args;
        item.defaultSelected = isDefault;
        g_items.push_back(item);
    }

    return !g_items.empty();
}

static void LoadCustomPresetsFromFile(const std::wstring& path) {
    if (!PathFileExistsW(path.c_str())) return;
    auto sections = GetIniSections(path);
    for (const auto& sec : sections) {
        if (sec.rfind(L"CustomPreset.", 0) != 0) continue;
        std::wstring name = sec.substr(13);
        std::wstring displayName = GetIniString(sec, L"Name", name, path);
        std::wstring p = GetIniString(sec, L"Path", L"", path);
        std::wstring a = GetIniString(sec, L"Args", L"", path);
        if (displayName.empty()) displayName = name;
        if (p.empty()) continue;

        std::wstring key = ToLower(displayName);
        auto it = std::find_if(g_customPresets.begin(), g_customPresets.end(), [&](const CustomPreset& c) {
            return ToLower(c.name) == key;
        });
        if (it == g_customPresets.end()) {
            g_customPresets.push_back({ displayName, p, a });
        } else {
            it->path = p;
            it->args = a;
        }
    }
}

static void LoadUsersFromFile(const std::wstring& path) {
    if (!PathFileExistsW(path.c_str())) return;
    auto sections = GetIniSections(path);
    for (const auto& sec : sections) {
        if (sec.rfind(L"User.", 0) != 0) continue;
        std::wstring name = GetIniString(sec, L"Name", sec.substr(5), path);
        std::wstring groups = GetIniString(sec, L"Groups", L"", path);
        if (name.empty()) continue;
        g_users.push_back({ name, groups });
    }
}

static void LoadCustomPresets() {
    g_customPresets.clear();
    if (!g_iniPath.empty()) {
        LoadCustomPresetsFromFile(g_iniPath);
    }
}

static void LoadUsers() {
    g_users.clear();
    if (!g_iniPath.empty()) {
        LoadUsersFromFile(g_iniPath);
    }
}

static void InitCustomListColumns() {
    if (!g_hCustomList) return;
    ListView_DeleteAllItems(g_hCustomList);
    while (ListView_DeleteColumn(g_hCustomList, 0)) {}

    LVCOLUMNW col{};
    col.mask = LVCF_TEXT | LVCF_WIDTH;
    col.pszText = const_cast<LPWSTR>(L"Name");
    col.cx = 180;
    ListView_InsertColumn(g_hCustomList, 0, &col);
    col.pszText = const_cast<LPWSTR>(L"Path");
    col.cx = 360;
    ListView_InsertColumn(g_hCustomList, 1, &col);
    col.pszText = const_cast<LPWSTR>(L"Args");
    col.cx = 240;
    ListView_InsertColumn(g_hCustomList, 2, &col);
}

static void PopulateCustomList() {
    if (!g_hCustomList) return;
    ListView_DeleteAllItems(g_hCustomList);
    for (size_t i = 0; i < g_customPresets.size(); ++i) {
        const auto& p = g_customPresets[i];
        LVITEMW lvi{};
        lvi.mask = LVIF_TEXT | LVIF_PARAM;
        lvi.iItem = static_cast<int>(i);
        lvi.pszText = const_cast<LPWSTR>(p.name.c_str());
        lvi.lParam = static_cast<LPARAM>(i);
        ListView_InsertItem(g_hCustomList, &lvi);
        ListView_SetItemText(g_hCustomList, static_cast<int>(i), 1, const_cast<LPWSTR>(p.path.c_str()));
        ListView_SetItemText(g_hCustomList, static_cast<int>(i), 2, const_cast<LPWSTR>(p.args.c_str()));
    }
}

static void InitUserListColumns() {
    if (!g_hUserList) return;
    ListView_DeleteAllItems(g_hUserList);
    while (ListView_DeleteColumn(g_hUserList, 0)) {}

    LVCOLUMNW col{};
    col.mask = LVCF_TEXT | LVCF_WIDTH;
    col.pszText = const_cast<LPWSTR>(L"User");
    col.cx = 200;
    ListView_InsertColumn(g_hUserList, 0, &col);
    col.pszText = const_cast<LPWSTR>(L"Groups");
    col.cx = 260;
    ListView_InsertColumn(g_hUserList, 1, &col);
}

static void PopulateUserList() {
    if (!g_hUserList) return;
    ListView_DeleteAllItems(g_hUserList);
    for (size_t i = 0; i < g_users.size(); ++i) {
        const auto& u = g_users[i];
        LVITEMW lvi{};
        lvi.mask = LVIF_TEXT | LVIF_PARAM;
        lvi.iItem = static_cast<int>(i);
        lvi.pszText = const_cast<LPWSTR>(u.name.c_str());
        lvi.lParam = static_cast<LPARAM>(i);
        ListView_InsertItem(g_hUserList, &lvi);
        ListView_SetItemText(g_hUserList, static_cast<int>(i), 1, const_cast<LPWSTR>(u.groups.c_str()));
    }
}

static void InitBrowserListColumns() {
    if (!g_hBrowserList) return;
    ListView_DeleteAllItems(g_hBrowserList);
    while (ListView_DeleteColumn(g_hBrowserList, 0)) {}

    LVCOLUMNW col{};
    col.mask = LVCF_TEXT | LVCF_WIDTH;
    col.pszText = const_cast<LPWSTR>(L"Browser");
    col.cx = 200;
    ListView_InsertColumn(g_hBrowserList, 0, &col);
    col.pszText = const_cast<LPWSTR>(L"Pfad");
    col.cx = 380;
    ListView_InsertColumn(g_hBrowserList, 1, &col);
    col.pszText = const_cast<LPWSTR>(L"Backup");
    col.cx = 80;
    ListView_InsertColumn(g_hBrowserList, 2, &col);
}

static void PopulateBrowserList() {
    if (!g_hBrowserList) return;
    ListView_DeleteAllItems(g_hBrowserList);
    for (size_t i = 0; i < g_browsers.size(); ++i) {
        const auto& b = g_browsers[i];
        LVITEMW lvi{};
        lvi.mask = LVIF_TEXT | LVIF_PARAM;
        lvi.iItem = static_cast<int>(i);
        lvi.pszText = const_cast<LPWSTR>(b.name.c_str());
        lvi.lParam = static_cast<LPARAM>(i);
        ListView_InsertItem(g_hBrowserList, &lvi);
        ListView_SetItemText(g_hBrowserList, static_cast<int>(i), 1, const_cast<LPWSTR>(b.path.c_str()));
        bool exists = PathFileExistsW(b.path.c_str()) != FALSE;
        ListView_SetCheckState(g_hBrowserList, static_cast<int>(i), exists ? TRUE : FALSE);
    }
    UpdateBrowserBackupStatus();
}

static void SelectAllBrowsers(bool checked) {
    if (!g_hBrowserList) return;
    for (int i = 0; i < static_cast<int>(g_browsers.size()); ++i) {
        ListView_SetCheckState(g_hBrowserList, i, checked ? TRUE : FALSE);
    }
}

static void UpdateBrowserBackupStatus() {
    if (!g_hBrowserList) return;
    std::wstring root = Trim(GetEditText(g_hBrowserPath));
    std::wstring browsersRoot = root.empty() ? L"" : PathJoin(root, L"Browsers");
    for (int i = 0; i < static_cast<int>(g_browsers.size()); ++i) {
        const auto& b = g_browsers[i];
        std::wstring status = L"Nein";
        if (!browsersRoot.empty()) {
            std::wstring backupPath = PathJoin(browsersRoot, b.id);
            if (PathFileExistsW(backupPath.c_str())) {
                status = L"Ja";
            }
        }
        ListView_SetItemText(g_hBrowserList, i, 2, const_cast<LPWSTR>(status.c_str()));
    }
}

static void InitMigrationListColumns() {
    if (!g_hMigrationList) return;
    ListView_DeleteAllItems(g_hMigrationList);
    while (ListView_DeleteColumn(g_hMigrationList, 0)) {}

    LVCOLUMNW col{};
    col.mask = LVCF_TEXT | LVCF_WIDTH;
    col.pszText = const_cast<LPWSTR>(L"Item");
    col.cx = 200;
    ListView_InsertColumn(g_hMigrationList, 0, &col);
    col.pszText = const_cast<LPWSTR>(L"Quelle");
    col.cx = 360;
    ListView_InsertColumn(g_hMigrationList, 1, &col);
    col.pszText = const_cast<LPWSTR>(L"Backup");
    col.cx = 80;
    ListView_InsertColumn(g_hMigrationList, 2, &col);
}

static void PopulateMigrationList() {
    if (!g_hMigrationList) return;
    ListView_DeleteAllItems(g_hMigrationList);
    for (size_t i = 0; i < g_migrationItems.size(); ++i) {
        const auto& item = g_migrationItems[i];
        LVITEMW lvi{};
        lvi.mask = LVIF_TEXT | LVIF_PARAM;
        lvi.iItem = static_cast<int>(i);
        lvi.pszText = const_cast<LPWSTR>(item.name.c_str());
        lvi.lParam = static_cast<LPARAM>(i);
        ListView_InsertItem(g_hMigrationList, &lvi);
        ListView_SetItemText(g_hMigrationList, static_cast<int>(i), 1, const_cast<LPWSTR>(item.path.c_str()));

        bool exists = false;
        if (item.kind == MigrationKind::Programs) {
            exists = true;
        } else if (!item.path.empty() && item.path != L"Automatisch" && item.path != L"Registry") {
            exists = PathFileExistsW(item.path.c_str()) != FALSE;
        } else if (item.kind == MigrationKind::Thunderbird) {
            exists = (!item.path.empty() && PathFileExistsW(item.path.c_str()));
        } else if (item.kind == MigrationKind::Outlook) {
            std::wstring doc = GetKnownFolderPath(FOLDERID_Documents);
            std::wstring local = GetLocalAppData();
            std::wstring p1 = doc.empty() ? L"" : PathJoin(doc, L"Outlook Files");
            std::wstring p2 = local.empty() ? L"" : PathJoin(local, L"Microsoft\\Outlook");
            if (!p1.empty() && PathFileExistsW(p1.c_str())) exists = true;
            if (!p2.empty() && PathFileExistsW(p2.c_str())) exists = true;
        }

        ListView_SetCheckState(g_hMigrationList, static_cast<int>(i), exists ? TRUE : FALSE);
    }
    UpdateMigrationBackupStatus();
}

static void SelectAllMigration(bool checked) {
    if (!g_hMigrationList) return;
    for (int i = 0; i < static_cast<int>(g_migrationItems.size()); ++i) {
        ListView_SetCheckState(g_hMigrationList, i, checked ? TRUE : FALSE);
    }
}

static std::wstring GetMigrationBackupPath(const MigrationItem& item, const std::wstring& root) {
    if (root.empty()) return L"";
    if (item.kind == MigrationKind::Programs) {
        return PathJoin(PathJoin(root, L"Programs"), L"InstalledPrograms.csv");
    }
    if (item.kind == MigrationKind::Thunderbird) {
        return PathJoin(PathJoin(root, L"Email"), L"Thunderbird");
    }
    if (item.kind == MigrationKind::Outlook) {
        return PathJoin(PathJoin(root, L"Email"), L"Outlook");
    }
    return PathJoin(PathJoin(root, L"UserData"), item.id);
}

static void UpdateMigrationBackupStatus() {
    if (!g_hMigrationList) return;
    std::wstring root = Trim(GetEditText(g_hMigrationPath));
    for (int i = 0; i < static_cast<int>(g_migrationItems.size()); ++i) {
        const auto& item = g_migrationItems[i];
        std::wstring status = L"Nein";
        std::wstring backupPath = GetMigrationBackupPath(item, root);
        if (!backupPath.empty() && PathFileExistsW(backupPath.c_str())) {
            status = L"Ja";
        }
        ListView_SetItemText(g_hMigrationList, i, 2, const_cast<LPWSTR>(status.c_str()));
    }
}

static std::wstring GetFileBaseName(const std::wstring& path) {
    wchar_t fileName[MAX_PATH];
    lstrcpynW(fileName, path.c_str(), MAX_PATH);
    PathStripPathW(fileName);
    PathRemoveExtensionW(fileName);
    return fileName;
}

static std::vector<std::wstring> SplitGroups(const std::wstring& s) {
    std::vector<std::wstring> out;
    std::wstringstream ss(s);
    std::wstring item;
    while (std::getline(ss, item, L',')) {
        item = Trim(item);
        if (!item.empty()) out.push_back(item);
    }
    return out;
}

static void AddCustomPresetFromFields() {
    std::wstring name = GetEditText(g_hCustomName);
    std::wstring path = GetEditText(g_hCustomPath);
    std::wstring args = GetEditText(g_hCustomArgs);
    if (path.empty()) {
        MessageBoxW(g_hWnd, L"Bitte eine EXE/MSI auswaehlen.", kAppTitle, MB_ICONWARNING);
        return;
    }
    if (name.empty()) {
        name = GetFileBaseName(path);
    }
    std::wstring key = ToLower(name);
    auto it = std::find_if(g_customPresets.begin(), g_customPresets.end(), [&](const CustomPreset& c) {
        return ToLower(c.name) == key;
    });
    if (it != g_customPresets.end()) {
        it->path = path;
        it->args = args;
        AppendLog(L"Custom preset updated: " + name);
    } else {
        CustomPreset preset{ name, path, args };
        g_customPresets.push_back(preset);
        AppendLog(L"Custom preset added: " + name);
    }
    PopulateCustomList();
}

static void AddUserFromFields() {
    std::wstring name = GetEditText(g_hUserName);
    std::wstring groups = GetEditText(g_hUserGroups);
    if (name.empty()) {
        MessageBoxW(g_hWnd, L"Bitte einen Benutzernamen angeben.", kAppTitle, MB_ICONWARNING);
        return;
    }
    std::wstring key = ToLower(name);
    auto it = std::find_if(g_users.begin(), g_users.end(), [&](const UserItem& u) {
        return ToLower(u.name) == key;
    });
    if (it != g_users.end()) {
        it->groups = groups;
        AppendLog(L"User updated: " + name);
    } else {
        g_users.push_back({ name, groups });
        AppendLog(L"User added: " + name);
    }
    PopulateUserList();
}

static void RemoveSelectedUsers() {
    if (!g_hUserList) return;
    int idx = ListView_GetNextItem(g_hUserList, -1, LVNI_SELECTED);
    if (idx == -1) {
        MessageBoxW(g_hWnd, L"Bitte einen User auswaehlen.", kAppTitle, MB_ICONWARNING);
        return;
    }
    std::vector<int> indices;
    while (idx != -1) {
        indices.push_back(idx);
        idx = ListView_GetNextItem(g_hUserList, idx, LVNI_SELECTED);
    }
    std::sort(indices.rbegin(), indices.rend());
    for (int i : indices) {
        if (i >= 0 && i < static_cast<int>(g_users.size())) {
            g_users.erase(g_users.begin() + i);
        }
    }
    PopulateUserList();
    AppendLog(L"Users removed.");
}

static void RemoveSelectedCustomPresets() {
    if (!g_hCustomList) return;
    int idx = ListView_GetNextItem(g_hCustomList, -1, LVNI_SELECTED);
    if (idx == -1) {
        MessageBoxW(g_hWnd, L"Bitte einen Eintrag auswaehlen.", kAppTitle, MB_ICONWARNING);
        return;
    }
    std::vector<int> indices;
    while (idx != -1) {
        indices.push_back(idx);
        idx = ListView_GetNextItem(g_hCustomList, idx, LVNI_SELECTED);
    }
    std::sort(indices.rbegin(), indices.rend());
    for (int i : indices) {
        if (i >= 0 && i < static_cast<int>(g_customPresets.size())) {
            g_customPresets.erase(g_customPresets.begin() + i);
        }
    }
    PopulateCustomList();
    AppendLog(L"Custom presets removed.");
}

static void LoadConfigFromPath(const std::wstring& path) {
    if (path.empty() || !PathFileExistsW(path.c_str())) {
        MessageBoxW(g_hWnd, L"Config-Datei nicht gefunden.", kAppTitle, MB_ICONWARNING);
        return;
    }
    g_iniPath = path;
    if (g_hConfigPath) {
        SetWindowTextW(g_hConfigPath, g_iniPath.c_str());
    }
    g_items.clear();
    if (!LoadConfigFile(g_iniPath)) {
        MessageBoxW(g_hWnd, L"Config konnte nicht geladen werden.", kAppTitle, MB_ICONWARNING);
        return;
    }
    g_configLoaded = true;
    if (g_hConfigPath) {
        SetWindowTextW(g_hConfigPath, g_iniPath.c_str());
    }
    LoadCustomPresets();
    LoadUsers();
    PopulateCustomList();
    PopulateUserList();
    PopulateList();

    SetChecked(g_hChkFastStartup, g_power.disableFastStartup);
    SetChecked(g_hChkHibernateAC, g_power.hibernateAC.enabled);
    SetEditInt(g_hEditHibernateAC, g_power.hibernateAC.minutes);
    SetChecked(g_hChkMonitorAC, g_power.monitorAC.enabled);
    SetEditInt(g_hEditMonitorAC, g_power.monitorAC.minutes);
    SetChecked(g_hChkSleepAC, g_power.sleepAC.enabled);
    SetEditInt(g_hEditSleepAC, g_power.sleepAC.minutes);
    SetChecked(g_hChkHibernateDC, g_power.hibernateDC.enabled);
    SetEditInt(g_hEditHibernateDC, g_power.hibernateDC.minutes);
    SetChecked(g_hChkMonitorDC, g_power.monitorDC.enabled);
    SetEditInt(g_hEditMonitorDC, g_power.monitorDC.minutes);

    SetChecked(g_hChkJoinEnable, g_join.enabled);
    SendMessageW(g_hRadioWorkgroup, BM_SETCHECK, g_join.type == JoinType::Workgroup ? BST_CHECKED : BST_UNCHECKED, 0);
    SendMessageW(g_hRadioDomain, BM_SETCHECK, g_join.type == JoinType::Domain ? BST_CHECKED : BST_UNCHECKED, 0);
    SetWindowTextW(g_hJoinTarget, g_join.target.c_str());
    if (g_join.hostname.empty()) {
        g_join.hostname = GetCurrentHostname();
    }
    SetWindowTextW(g_hJoinHostname, g_join.hostname.c_str());

    AppendLog(L"Config loaded: " + path);
}

static void SaveConfigToPath(const std::wstring& path) {
    if (path.empty()) {
        MessageBoxW(g_hWnd, L"Bitte einen Config-Pfad angeben.", kAppTitle, MB_ICONWARNING);
        return;
    }
    g_iniPath = path;
    if (g_hConfigPath) {
        SetWindowTextW(g_hConfigPath, g_iniPath.c_str());
    }

    // Update power settings from UI
    g_power.disableFastStartup = IsChecked(g_hChkFastStartup);
    g_power.hibernateAC.enabled = IsChecked(g_hChkHibernateAC);
    g_power.hibernateAC.minutes = ClampNonNegative(GetEditInt(g_hEditHibernateAC, g_power.hibernateAC.minutes));
    g_power.monitorAC.enabled = IsChecked(g_hChkMonitorAC);
    g_power.monitorAC.minutes = ClampNonNegative(GetEditInt(g_hEditMonitorAC, g_power.monitorAC.minutes));
    g_power.sleepAC.enabled = IsChecked(g_hChkSleepAC);
    g_power.sleepAC.minutes = ClampNonNegative(GetEditInt(g_hEditSleepAC, g_power.sleepAC.minutes));
    g_power.hibernateDC.enabled = IsChecked(g_hChkHibernateDC);
    g_power.hibernateDC.minutes = ClampNonNegative(GetEditInt(g_hEditHibernateDC, g_power.hibernateDC.minutes));
    g_power.monitorDC.enabled = IsChecked(g_hChkMonitorDC);
    g_power.monitorDC.minutes = ClampNonNegative(GetEditInt(g_hEditMonitorDC, g_power.monitorDC.minutes));

    WritePrivateProfileStringW(L"Power", nullptr, nullptr, g_iniPath.c_str());
    WritePrivateProfileStringW(L"Power", L"DisableFastStartup", g_power.disableFastStartup ? L"1" : L"0", g_iniPath.c_str());
    WritePrivateProfileStringW(L"Power", L"EnableHibernateAC", g_power.hibernateAC.enabled ? L"1" : L"0", g_iniPath.c_str());
    WritePrivateProfileStringW(L"Power", L"HibernateACMinutes", std::to_wstring(g_power.hibernateAC.minutes).c_str(), g_iniPath.c_str());
    WritePrivateProfileStringW(L"Power", L"EnableMonitorAC", g_power.monitorAC.enabled ? L"1" : L"0", g_iniPath.c_str());
    WritePrivateProfileStringW(L"Power", L"MonitorACMinutes", std::to_wstring(g_power.monitorAC.minutes).c_str(), g_iniPath.c_str());
    WritePrivateProfileStringW(L"Power", L"EnableSleepAC", g_power.sleepAC.enabled ? L"1" : L"0", g_iniPath.c_str());
    WritePrivateProfileStringW(L"Power", L"SleepACMinutes", std::to_wstring(g_power.sleepAC.minutes).c_str(), g_iniPath.c_str());
    WritePrivateProfileStringW(L"Power", L"EnableHibernateDC", g_power.hibernateDC.enabled ? L"1" : L"0", g_iniPath.c_str());
    WritePrivateProfileStringW(L"Power", L"HibernateDCMinutes", std::to_wstring(g_power.hibernateDC.minutes).c_str(), g_iniPath.c_str());
    WritePrivateProfileStringW(L"Power", L"EnableMonitorDC", g_power.monitorDC.enabled ? L"1" : L"0", g_iniPath.c_str());
    WritePrivateProfileStringW(L"Power", L"MonitorDCMinutes", std::to_wstring(g_power.monitorDC.minutes).c_str(), g_iniPath.c_str());

    // Join settings
    WritePrivateProfileStringW(L"Join", nullptr, nullptr, g_iniPath.c_str());
    WritePrivateProfileStringW(L"Join", L"Enabled", IsChecked(g_hChkJoinEnable) ? L"1" : L"0", g_iniPath.c_str());
    WritePrivateProfileStringW(L"Join", L"Type", (SendMessageW(g_hRadioDomain, BM_GETCHECK, 0, 0) == BST_CHECKED) ? L"domain" : L"workgroup", g_iniPath.c_str());
    WritePrivateProfileStringW(L"Join", L"Target", GetEditText(g_hJoinTarget).c_str(), g_iniPath.c_str());
    WritePrivateProfileStringW(L"Join", L"Hostname", GetEditText(g_hJoinHostname).c_str(), g_iniPath.c_str());

    // Clear existing custom presets sections
    auto sections = GetIniSections(g_iniPath);
    for (const auto& sec : sections) {
        if (sec.rfind(L"CustomPreset.", 0) == 0) {
            WritePrivateProfileStringW(sec.c_str(), nullptr, nullptr, g_iniPath.c_str());
        }
        if (sec.rfind(L"User.", 0) == 0) {
            WritePrivateProfileStringW(sec.c_str(), nullptr, nullptr, g_iniPath.c_str());
        }
    }
    for (const auto& p : g_customPresets) {
        if (p.name.empty() || p.path.empty()) continue;
        std::wstring section = L"CustomPreset." + p.name;
        WritePrivateProfileStringW(section.c_str(), L"Name", p.name.c_str(), g_iniPath.c_str());
        WritePrivateProfileStringW(section.c_str(), L"Path", p.path.c_str(), g_iniPath.c_str());
        WritePrivateProfileStringW(section.c_str(), L"Args", p.args.c_str(), g_iniPath.c_str());
    }

    // Save users
    for (const auto& u : g_users) {
        if (u.name.empty()) continue;
        std::wstring section = L"User." + u.name;
        WritePrivateProfileStringW(section.c_str(), L"Name", u.name.c_str(), g_iniPath.c_str());
        WritePrivateProfileStringW(section.c_str(), L"Groups", u.groups.c_str(), g_iniPath.c_str());
    }

    // Save current app selections as Default flags
    for (size_t i = 0; i < g_items.size(); ++i) {
        const auto& item = g_items[i];
        std::wstring section = L"App." + item.id;
        bool checked = ListView_GetCheckState(g_hList, static_cast<int>(i)) != FALSE;
        WritePrivateProfileStringW(section.c_str(), L"Default", checked ? L"1" : L"0", g_iniPath.c_str());
    }

    AppendLog(L"Config saved: " + g_iniPath);
}

static void AppendLog(const std::wstring& line) {
    if (!g_hLog) return;
    int len = GetWindowTextLengthW(g_hLog);
    SendMessageW(g_hLog, EM_SETSEL, len, len);
    std::wstring msg = line + L"\r\n";
    SendMessageW(g_hLog, EM_REPLACESEL, FALSE, reinterpret_cast<LPARAM>(msg.c_str()));
}

static LRESULT CALLBACK PageWndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_COMMAND:
    case WM_NOTIFY: {
        HWND target = GetAncestor(hWnd, GA_ROOT);
        if (target) {
            return SendMessageW(target, msg, wParam, lParam);
        }
        return 0;
    }
    default:
        break;
    }
    return DefWindowProcW(hWnd, msg, wParam, lParam);
}

struct JoinPromptState {
    bool done = false;
    bool ok = false;
    std::wstring hostname;
    HWND hHost = nullptr;
};

static LRESULT CALLBACK JoinPromptProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    auto state = reinterpret_cast<JoinPromptState*>(GetWindowLongPtrW(hWnd, GWLP_USERDATA));
    switch (msg) {
    case WM_CREATE: {
        auto cs = reinterpret_cast<LPCREATESTRUCTW>(lParam);
        state = reinterpret_cast<JoinPromptState*>(cs->lpCreateParams);
        SetWindowLongPtrW(hWnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(state));

        HFONT hFont = (HFONT)GetStockObject(DEFAULT_GUI_FONT);

        CreateWindowW(L"STATIC", L"Hostname:", WS_CHILD | WS_VISIBLE,
            12, 12, 120, 18, hWnd, nullptr, g_hInst, nullptr);
        state->hHost = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
            WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL, 12, 32, 360, 24, hWnd, nullptr, g_hInst, nullptr);

        HWND hOk = CreateWindowW(L"BUTTON", L"OK", WS_CHILD | WS_VISIBLE | BS_DEFPUSHBUTTON,
            210, 80, 80, 26, hWnd, (HMENU)IDOK, g_hInst, nullptr);
        HWND hCancel = CreateWindowW(L"BUTTON", L"Abbrechen", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            292, 80, 80, 26, hWnd, (HMENU)IDCANCEL, g_hInst, nullptr);

        SendMessageW(state->hHost, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(hOk, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(hCancel, WM_SETFONT, (WPARAM)hFont, TRUE);

        if (!state->hostname.empty()) {
            SetWindowTextW(state->hHost, state->hostname.c_str());
        }
        return 0;
    }
    case WM_COMMAND:
        if (LOWORD(wParam) == IDOK) {
            state->hostname = GetEditText(state->hHost);
            state->ok = true;
            state->done = true;
            DestroyWindow(hWnd);
            return 0;
        }
        if (LOWORD(wParam) == IDCANCEL) {
            state->done = true;
            DestroyWindow(hWnd);
            return 0;
        }
        break;
    case WM_CLOSE:
        if (state) {
            state->done = true;
        }
        DestroyWindow(hWnd);
        return 0;
    default:
        break;
    }
    return DefWindowProcW(hWnd, msg, wParam, lParam);
}

static bool PromptHostnameOnly(HWND parent, std::wstring& hostname) {
    JoinPromptState state{};
    state.hostname = hostname;

    EnableWindow(parent, FALSE);
    HWND hDlg = CreateWindowExW(WS_EX_DLGMODALFRAME, kJoinPromptClass, L"Hostname",
        WS_POPUP | WS_CAPTION | WS_SYSMENU, CW_USEDEFAULT, CW_USEDEFAULT, 400, 150,
        parent, nullptr, g_hInst, &state);
    if (!hDlg) {
        EnableWindow(parent, TRUE);
        return false;
    }
    ShowWindow(hDlg, SW_SHOW);
    UpdateWindow(hDlg);

    MSG msg{};
    while (!state.done && GetMessageW(&msg, nullptr, 0, 0)) {
        if (!IsDialogMessageW(hDlg, &msg)) {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
    }
    EnableWindow(parent, TRUE);
    SetActiveWindow(parent);

    if (state.ok) {
        hostname = state.hostname;
    }
    return state.ok;
}

static bool IsElevated() {
    HANDLE token = nullptr;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return false;
    TOKEN_ELEVATION elevation;
    DWORD size = 0;
    bool elevated = false;
    if (GetTokenInformation(token, TokenElevation, &elevation, sizeof(elevation), &size)) {
        elevated = elevation.TokenIsElevated != 0;
    }
    CloseHandle(token);
    return elevated;
}

static std::wstring QuoteIfNeeded(const std::wstring& s) {
    if (s.find_first_of(L" \t") == std::wstring::npos) return s;
    return L"\"" + s + L"\"";
}

static bool RunProcess(const std::wstring& exe, const std::wstring& args, DWORD& exitCode) {
    std::wstring cmd = QuoteIfNeeded(exe);
    if (!args.empty()) {
        cmd += L" ";
        cmd += args;
    }
    std::vector<wchar_t> cmdBuf(cmd.begin(), cmd.end());
    cmdBuf.push_back(L'\0');

    STARTUPINFOW si{};
    si.cb = sizeof(si);
    PROCESS_INFORMATION pi{};
    BOOL ok = CreateProcessW(nullptr, cmdBuf.data(), nullptr, nullptr, FALSE, 0, nullptr, nullptr, &si, &pi);
    if (!ok) {
        exitCode = GetLastError();
        return false;
    }
    WaitForSingleObject(pi.hProcess, INFINITE);
    GetExitCodeProcess(pi.hProcess, &exitCode);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    return true;
}

static bool ExitCodeSuccess(DWORD code) {
    return code == 0 || code == 3010;
}

static bool RunInstaller(const AppItem& item, DWORD& exitCode) {
    std::wstring type = item.type;
    std::transform(type.begin(), type.end(), type.begin(), ::towlower);

    if (type == L"choco") {
        if (!EnsureChocolateyInstalled()) {
            exitCode = ERROR_FILE_NOT_FOUND;
            return false;
        }
        std::wstring choco = GetChocoExePath();
        std::wstring args = NormalizeChocoArgs(item.args);
        return RunProcess(choco, args, exitCode);
    }

    if (type == L"msi") {
        if (!PathFileExistsW(item.path.c_str())) {
            exitCode = ERROR_FILE_NOT_FOUND;
            return false;
        }
        std::wstring args = L"/i " + QuoteIfNeeded(item.path) + L" /qn /norestart";
        if (!item.args.empty()) {
            args += L" ";
            args += item.args;
        }
        return RunProcess(L"msiexec.exe", args, exitCode);
    }

    std::wstring exe = item.path.empty() ? item.name : item.path;
    if (type != L"choco" && !item.path.empty() && !PathFileExistsW(item.path.c_str())) {
        exitCode = ERROR_FILE_NOT_FOUND;
        return false;
    }
    return RunProcess(exe, item.args, exitCode);
}

static void PopulateList() {
    ListView_DeleteAllItems(g_hList);
    for (size_t i = 0; i < g_items.size(); ++i) {
        LVITEMW lvi{};
        lvi.mask = LVIF_TEXT | LVIF_PARAM;
        lvi.iItem = static_cast<int>(i);
        lvi.pszText = const_cast<LPWSTR>(g_items[i].name.c_str());
        lvi.lParam = static_cast<LPARAM>(i);
        ListView_InsertItem(g_hList, &lvi);
        ListView_SetCheckState(g_hList, static_cast<int>(i), g_items[i].defaultSelected ? TRUE : FALSE);
    }
}

static void ApplyPreset() {
    for (int i = 0; i < static_cast<int>(g_items.size()); ++i) {
        std::wstring id = g_items[i].id;
        std::transform(id.begin(), id.end(), id.begin(), ::towlower);
        bool match = std::find(g_presetIds.begin(), g_presetIds.end(), id) != g_presetIds.end();
        ListView_SetCheckState(g_hList, i, match ? TRUE : FALSE);
    }
    AppendLog(L"Preset applied: " + g_presetName);
}

static void SelectAll(bool value) {
    for (int i = 0; i < static_cast<int>(g_items.size()); ++i) {
        ListView_SetCheckState(g_hList, i, value ? TRUE : FALSE);
    }
}

static std::wstring GetEditText(HWND hEdit) {
    int len = GetWindowTextLengthW(hEdit);
    std::wstring text(len, L'\0');
    if (len > 0) {
        GetWindowTextW(hEdit, &text[0], len + 1);
    }
    return Trim(text);
}

static int GetEditInt(HWND hEdit, int def) {
    std::wstring text = GetEditText(hEdit);
    if (text.empty()) return def;
    return _wtoi(text.c_str());
}

static void SetEditInt(HWND hEdit, int value) {
    std::wstring text = std::to_wstring(value);
    SetWindowTextW(hEdit, text.c_str());
}

static bool IsChecked(HWND hWnd) {
    return SendMessageW(hWnd, BM_GETCHECK, 0, 0) == BST_CHECKED;
}

static void SetChecked(HWND hWnd, bool checked) {
    SendMessageW(hWnd, BM_SETCHECK, checked ? BST_CHECKED : BST_UNCHECKED, 0);
}

static int ClampNonNegative(int value) {
    return value < 0 ? 0 : value;
}

static void InstallSelected() {
    AppendLog(L"Starting installation...");
    for (int i = 0; i < static_cast<int>(g_items.size()); ++i) {
        if (!ListView_GetCheckState(g_hList, i)) continue;
        const auto& item = g_items[i];
        AppendLog(L"Installing: " + item.name);
        DWORD exitCode = 0;
        if (!RunInstaller(item, exitCode)) {
            AppendLog(L"  FAILED (error/exit code): " + std::to_wstring(exitCode));
        } else {
            AppendLog(L"  OK (exit code): " + std::to_wstring(exitCode));
        }
    }
    AppendLog(L"Done.");
}

static void RunCustomInstaller() {
    std::wstring path = GetEditText(g_hCustomPath);
    std::wstring args = GetEditText(g_hCustomArgs);
    int sel = g_hCustomList ? ListView_GetNextItem(g_hCustomList, -1, LVNI_SELECTED) : -1;
    if (sel >= 0 && sel < static_cast<int>(g_customPresets.size())) {
        path = g_customPresets[sel].path;
        args = g_customPresets[sel].args;
    }
    if (path.empty()) {
        MessageBoxW(g_hWnd, L"Please select a file first.", kAppTitle, MB_ICONWARNING);
        return;
    }
    std::wstring ext = PathFindExtensionW(path.c_str());
    std::transform(ext.begin(), ext.end(), ext.begin(), ::towlower);

    AppItem item;
    item.name = L"Custom";
    item.path = path;
    item.args = args;
    item.type = (ext == L".msi") ? L"msi" : L"exe";

    AppendLog(L"Installing custom: " + path);
    if (item.type == L"msi") {
        DWORD exitCode = 0;
        if (!RunInstaller(item, exitCode)) {
            AppendLog(L"  FAILED (error/exit code): " + std::to_wstring(exitCode));
        } else {
            AppendLog(L"  OK (exit code): " + std::to_wstring(exitCode));
        }
        return;
    }

    if (!PathFileExistsW(path.c_str())) {
        AppendLog(L"  FAILED: file not found.");
        return;
    }

    auto runSilent = [&](const std::wstring& exePath, const std::wstring& baseArgs, const std::wstring& label) {
        std::vector<std::wstring> candidates;
        if (!baseArgs.empty()) {
            candidates.push_back(baseArgs);
        }
        auto addUnique = [&](const std::wstring& val) {
            if (std::find(candidates.begin(), candidates.end(), val) == candidates.end()) {
                candidates.push_back(val);
            }
        };

        addUnique(L"/S");
        addUnique(L"/s");
        addUnique(L"/silent");
        addUnique(L"/SILENT");
        addUnique(L"/verysilent");
        addUnique(L"/VERYSILENT");
        addUnique(L"/quiet");
        addUnique(L"/qn");
        addUnique(L"/s /quiet");
        addUnique(L"/S /quiet");
        addUnique(L"/s /silent");
        addUnique(L"/S /silent");
        addUnique(L"/quiet /norestart");
        addUnique(L"/passive /norestart");
        addUnique(L"/S /norestart");
        addUnique(L"/s /norestart");
        addUnique(L"/VERYSILENT /SUPPRESSMSGBOXES /NORESTART");
        addUnique(L"/SILENT /NORESTART");
        addUnique(L"/s /v\"/qn /norestart\"");
        addUnique(L"/S /v\"/qn /norestart\"");
        addUnique(L"/v\"/qn /norestart\"");
        addUnique(L"/s /v\"/qn\"");
        addUnique(L"/S /v\"/qn\"");
        addUnique(L"/s /v\"/quiet /norestart\"");
        addUnique(L"/S /v\"/quiet /norestart\"");

        bool success = false;
        for (const auto& cand : candidates) {
            AppendLog(L"  " + label + L" args: " + cand);
            DWORD exitCode = 0;
            if (!RunProcess(exePath, cand, exitCode)) {
                AppendLog(L"    FAILED (error/exit code): " + std::to_wstring(exitCode));
                continue;
            }
            AppendLog(L"    Exit code: " + std::to_wstring(exitCode));
            if (ExitCodeSuccess(exitCode)) {
                success = true;
                break;
            }
        }
        if (success) {
            AppendLog(L"  " + label + L" finished.");
        } else {
            AppendLog(L"  " + label + L" failed for all silent attempts.");
        }
        return success;
    };

    runSilent(path, args, L"Silent install");
}

static void InstallAllCustomPresets() {
    if (g_customPresets.empty()) {
        AppendLog(L"No custom presets defined.");
        return;
    }
    AppendLog(L"Installing all custom presets...");
    for (const auto& preset : g_customPresets) {
        std::wstring path = preset.path;
        if (path.empty()) continue;
        std::wstring ext = PathFindExtensionW(path.c_str());
        std::transform(ext.begin(), ext.end(), ext.begin(), ::towlower);

        AppendLog(L"Custom preset: " + preset.name);
        if (!PathFileExistsW(path.c_str())) {
            AppendLog(L"  FAILED: file not found.");
            continue;
        }

        if (ext == L".msi") {
            std::wstring args = L"/i " + QuoteIfNeeded(path) + L" /qn /norestart";
            if (!preset.args.empty()) {
                args += L" ";
                args += preset.args;
            }
            DWORD exitCode = 0;
            if (!RunProcess(L"msiexec.exe", args, exitCode)) {
                AppendLog(L"  FAILED (error/exit code): " + std::to_wstring(exitCode));
            } else {
                AppendLog(L"  OK (exit code): " + std::to_wstring(exitCode));
            }
        } else {
            std::wstring label = L"Silent install (" + preset.name + L")";
            std::wstring baseArgs = preset.args;
            std::vector<std::wstring> candidates;
            if (!baseArgs.empty()) {
                candidates.push_back(baseArgs);
            }
            auto addUnique = [&](const std::wstring& val) {
                if (std::find(candidates.begin(), candidates.end(), val) == candidates.end()) {
                    candidates.push_back(val);
                }
            };
            addUnique(L"/S");
            addUnique(L"/s");
            addUnique(L"/silent");
            addUnique(L"/SILENT");
            addUnique(L"/verysilent");
            addUnique(L"/VERYSILENT");
            addUnique(L"/quiet");
            addUnique(L"/qn");
            addUnique(L"/s /quiet");
            addUnique(L"/S /quiet");
            addUnique(L"/s /silent");
            addUnique(L"/S /silent");
            addUnique(L"/quiet /norestart");
            addUnique(L"/passive /norestart");
            addUnique(L"/S /norestart");
            addUnique(L"/s /norestart");
            addUnique(L"/VERYSILENT /SUPPRESSMSGBOXES /NORESTART");
            addUnique(L"/SILENT /NORESTART");
            addUnique(L"/s /v\"/qn /norestart\"");
            addUnique(L"/S /v\"/qn /norestart\"");
            addUnique(L"/v\"/qn /norestart\"");
            addUnique(L"/s /v\"/qn\"");
            addUnique(L"/S /v\"/qn\"");
            addUnique(L"/s /v\"/quiet /norestart\"");
            addUnique(L"/S /v\"/quiet /norestart\"");

            bool success = false;
            for (const auto& cand : candidates) {
                AppendLog(L"  " + label + L" args: " + cand);
                DWORD exitCode = 0;
                if (!RunProcess(path, cand, exitCode)) {
                    AppendLog(L"    FAILED (error/exit code): " + std::to_wstring(exitCode));
                    continue;
                }
                AppendLog(L"    Exit code: " + std::to_wstring(exitCode));
                if (ExitCodeSuccess(exitCode)) {
                    success = true;
                    break;
                }
            }
            if (success) {
                AppendLog(L"  " + label + L" finished.");
            } else {
                AppendLog(L"  " + label + L" failed for all silent attempts.");
            }
        }
    }
    AppendLog(L"Custom preset installs complete.");
}

static void CreateLocalUsers() {
    if (g_users.empty()) {
        AppendLog(L"No users to create.");
        return;
    }
    AppendLog(L"Creating local users...");
    for (const auto& u : g_users) {
        if (u.name.empty()) continue;
        std::wstring args = L"user \"" + u.name + L"\" \"\" /add /y";
        DWORD exitCode = 0;
        if (!RunProcess(L"net.exe", args, exitCode)) {
            AppendLog(L"  FAILED create user: " + u.name + L" (code " + std::to_wstring(exitCode) + L")");
            continue;
        }
        // allow blank password and prevent forced password change
        RunProcess(L"net.exe", L"user \"" + u.name + L"\" /passwordreq:no", exitCode);
        RunProcess(L"net.exe", L"user \"" + u.name + L"\" /passwordchg:no", exitCode);

        auto groups = SplitGroups(u.groups);
        for (const auto& g : groups) {
            std::wstring gargs = L"localgroup \"" + g + L"\" \"" + u.name + L"\" /add";
            RunProcess(L"net.exe", gargs, exitCode);
        }
        AppendLog(L"  User done: " + u.name);
    }
    AppendLog(L"User creation complete.");
}

static std::wstring EscapePsString(const std::wstring& s) {
    std::wstring out = s;
    size_t pos = 0;
    while ((pos = out.find(L"'", pos)) != std::wstring::npos) {
        out.insert(pos, L"'");
        pos += 2;
    }
    return out;
}

static void JoinDomainOrWorkgroup(JoinType type, const std::wstring& target, const std::wstring& hostname) {
    if (target.empty()) {
        AppendLog(L"Join skipped: target is empty.");
        return;
    }
    std::wstring tgt = EscapePsString(target);
    std::wstring host = EscapePsString(hostname);
    std::wstring cmd = L"-NoProfile -Command ";

    if (type == JoinType::Domain) {
        cmd += L"\"Add-Computer -DomainName '" + tgt + L"'";
        if (!host.empty()) {
            cmd += L" -NewName '" + host + L"'";
        }
        cmd += L" -Force -PassThru -Credential (Get-Credential)\"";
    } else {
        cmd += L"\"Add-Computer -WorkgroupName '" + tgt + L"'";
        if (!host.empty()) {
            cmd += L" -NewName '" + host + L"'";
        }
        cmd += L" -Force -PassThru\"";
    }

    AppendLog(L"Joining " + std::wstring(type == JoinType::Domain ? L"domain" : L"workgroup") + L": " + target);
    DWORD exitCode = 0;
    if (!RunProcess(L"powershell.exe", cmd, exitCode)) {
        AppendLog(L"  Join failed (code " + std::to_wstring(exitCode) + L")");
    } else {
        AppendLog(L"  Join command finished (code " + std::to_wstring(exitCode) + L")");
    }
}

static void JoinFromUI() {
    std::wstring target = GetEditText(g_hJoinTarget);
    std::wstring hostname = GetEditText(g_hJoinHostname);
    JoinType type = (SendMessageW(g_hRadioDomain, BM_GETCHECK, 0, 0) == BST_CHECKED) ? JoinType::Domain : JoinType::Workgroup;
    JoinDomainOrWorkgroup(type, target, hostname);
}

static void RunAll() {
    AppendLog(L"Run all started...");
    InstallSelected();
    InstallAllCustomPresets();
    CreateLocalUsers();
    ApplyPowerTweaks();
    if (IsChecked(g_hChkJoinEnable)) {
        JoinFromUI();
    }
    AppendLog(L"Run all finished.");
}

static void ApplyPowerTweaks() {
    AppendLog(L"Applying power tweaks...");

    if (IsChecked(g_hChkFastStartup)) {
        HKEY key = nullptr;
        LONG res = RegOpenKeyExW(HKEY_LOCAL_MACHINE, L"SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Power", 0, KEY_SET_VALUE, &key);
        if (res == ERROR_SUCCESS) {
            DWORD value = 0;
            res = RegSetValueExW(key, L"HiberbootEnabled", 0, REG_DWORD, reinterpret_cast<const BYTE*>(&value), sizeof(value));
            RegCloseKey(key);
        }
        if (res == ERROR_SUCCESS) {
            AppendLog(L"  Fast Startup disabled.");
        } else {
            AppendLog(L"  Failed to disable Fast Startup (error): " + std::to_wstring(res));
        }
    }

    auto applyPowercfg = [](const std::wstring& args, const std::wstring& label) {
        DWORD exitCode = 0;
        if (!RunProcess(L"powercfg.exe", args, exitCode)) {
            AppendLog(L"  " + label + L" FAILED (error/exit code): " + std::to_wstring(exitCode));
        } else {
            AppendLog(L"  " + label + L" OK (exit code): " + std::to_wstring(exitCode));
        }
    };

    if (IsChecked(g_hChkHibernateAC)) {
        int minutes = ClampNonNegative(GetEditInt(g_hEditHibernateAC, g_power.hibernateAC.minutes));
        applyPowercfg(L"/change -hibernate-timeout-ac " + std::to_wstring(minutes), L"Hibernate AC");
    }
    if (IsChecked(g_hChkMonitorAC)) {
        int minutes = ClampNonNegative(GetEditInt(g_hEditMonitorAC, g_power.monitorAC.minutes));
        applyPowercfg(L"/change -monitor-timeout-ac " + std::to_wstring(minutes), L"Monitor AC");
    }
    if (IsChecked(g_hChkSleepAC)) {
        int minutes = ClampNonNegative(GetEditInt(g_hEditSleepAC, g_power.sleepAC.minutes));
        applyPowercfg(L"/change -standby-timeout-ac " + std::to_wstring(minutes), L"Sleep AC");
    }
    if (IsChecked(g_hChkHibernateDC)) {
        int minutes = ClampNonNegative(GetEditInt(g_hEditHibernateDC, g_power.hibernateDC.minutes));
        applyPowercfg(L"/change -hibernate-timeout-dc " + std::to_wstring(minutes), L"Hibernate DC");
    }
    if (IsChecked(g_hChkMonitorDC)) {
        int minutes = ClampNonNegative(GetEditInt(g_hEditMonitorDC, g_power.monitorDC.minutes));
        applyPowercfg(L"/change -monitor-timeout-dc " + std::to_wstring(minutes), L"Monitor DC");
    }
    AppendLog(L"Power tweaks done.");
}

static void DoBrowse() {
    wchar_t fileName[MAX_PATH] = L"";
    OPENFILENAMEW ofn{};
    ofn.lStructSize = sizeof(ofn);
    ofn.hwndOwner = g_hWnd;
    ofn.lpstrFilter = L"Installer Files (*.exe;*.msi)\0*.exe;*.msi\0All Files\0*.*\0";
    ofn.lpstrFile = fileName;
    ofn.nMaxFile = MAX_PATH;
    ofn.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST;
    if (GetOpenFileNameW(&ofn)) {
        SetWindowTextW(g_hCustomPath, fileName);
        if (g_hCustomName) {
            std::wstring current = GetEditText(g_hCustomName);
            if (current.empty()) {
                std::wstring name = GetFileBaseName(fileName);
                SetWindowTextW(g_hCustomName, name.c_str());
            }
        }
    }
}

static void DoConfigBrowse() {
    wchar_t fileName[MAX_PATH] = L"";
    OPENFILENAMEW ofn{};
    ofn.lStructSize = sizeof(ofn);
    ofn.hwndOwner = g_hWnd;
    ofn.lpstrFilter = L"INI Files (*.ini)\0*.ini\0All Files\0*.*\0";
    ofn.lpstrFile = fileName;
    ofn.nMaxFile = MAX_PATH;
    ofn.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST;
    if (GetOpenFileNameW(&ofn)) {
        SetWindowTextW(g_hConfigPath, fileName);
    }
}

static void DoBrowserBrowse() {
    BROWSEINFOW bi{};
    bi.hwndOwner = g_hWnd;
    bi.ulFlags = BIF_RETURNONLYFSDIRS | BIF_NEWDIALOGSTYLE;
    bi.lpszTitle = L"Backup-Ordner auswaehlen";
    PIDLIST_ABSOLUTE pidl = SHBrowseForFolderW(&bi);
    if (!pidl) return;
    wchar_t path[MAX_PATH] = L"";
    if (SHGetPathFromIDListW(pidl, path)) {
        SetWindowTextW(g_hBrowserPath, path);
        UpdateBrowserBackupStatus();
    }
    CoTaskMemFree(pidl);
}

static void DoMigrationBrowse() {
    BROWSEINFOW bi{};
    bi.hwndOwner = g_hWnd;
    bi.ulFlags = BIF_RETURNONLYFSDIRS | BIF_NEWDIALOGSTYLE;
    bi.lpszTitle = L"Migrations-Backup auswaehlen";
    PIDLIST_ABSOLUTE pidl = SHBrowseForFolderW(&bi);
    if (!pidl) return;
    wchar_t path[MAX_PATH] = L"";
    if (SHGetPathFromIDListW(pidl, path)) {
        SetWindowTextW(g_hMigrationPath, path);
        UpdateMigrationBackupStatus();
    }
    CoTaskMemFree(pidl);
}

static void DoMigrationInstallerBrowse() {
    BROWSEINFOW bi{};
    bi.hwndOwner = g_hWnd;
    bi.ulFlags = BIF_RETURNONLYFSDIRS | BIF_NEWDIALOGSTYLE;
    bi.lpszTitle = L"Installer-Ordner auswaehlen";
    PIDLIST_ABSOLUTE pidl = SHBrowseForFolderW(&bi);
    if (!pidl) return;
    wchar_t path[MAX_PATH] = L"";
    if (SHGetPathFromIDListW(pidl, path)) {
        SetWindowTextW(g_hMigrationInstallerPath, path);
    }
    CoTaskMemFree(pidl);
}

static void ExportInstalledPrograms(const std::wstring& destDir) {
    EnsureDirExists(destDir);
    std::wstring csvPath = PathJoin(destDir, L"InstalledPrograms.csv");
    std::wstring txtPath = PathJoin(destDir, L"InstalledPrograms.txt");

    FILE* fcsv = nullptr;
    FILE* ftxt = nullptr;
    _wfopen_s(&fcsv, csvPath.c_str(), L"w, ccs=UTF-8");
    _wfopen_s(&ftxt, txtPath.c_str(), L"w, ccs=UTF-8");
    if (fcsv) {
        fputws(L"Name;Version;Publisher;InstallLocation\r\n", fcsv);
    }

    auto dumpKey = [&](HKEY root, const wchar_t* sub) {
        HKEY hKey = nullptr;
        if (RegOpenKeyExW(root, sub, 0, KEY_READ, &hKey) != ERROR_SUCCESS) {
            return;
        }
        DWORD index = 0;
        wchar_t nameBuf[256];
        DWORD nameLen = 256;
        while (RegEnumKeyExW(hKey, index, nameBuf, &nameLen, nullptr, nullptr, nullptr, nullptr) == ERROR_SUCCESS) {
            HKEY hApp = nullptr;
            if (RegOpenKeyExW(hKey, nameBuf, 0, KEY_READ, &hApp) == ERROR_SUCCESS) {
                wchar_t disp[512] = L"";
                wchar_t ver[128] = L"";
                wchar_t pub[256] = L"";
                wchar_t loc[512] = L"";
                DWORD sz = sizeof(disp);
                RegQueryValueExW(hApp, L"DisplayName", nullptr, nullptr, reinterpret_cast<LPBYTE>(disp), &sz);
                sz = sizeof(ver);
                RegQueryValueExW(hApp, L"DisplayVersion", nullptr, nullptr, reinterpret_cast<LPBYTE>(ver), &sz);
                sz = sizeof(pub);
                RegQueryValueExW(hApp, L"Publisher", nullptr, nullptr, reinterpret_cast<LPBYTE>(pub), &sz);
                sz = sizeof(loc);
                RegQueryValueExW(hApp, L"InstallLocation", nullptr, nullptr, reinterpret_cast<LPBYTE>(loc), &sz);
                if (disp[0] != L'\0') {
                    if (fcsv) {
                        fwprintf(fcsv, L"\"%s\";\"%s\";\"%s\";\"%s\"\r\n", disp, ver, pub, loc);
                    }
                    if (ftxt) {
                        fwprintf(ftxt, L"%s | %s | %s | %s\r\n", disp, ver, pub, loc);
                    }
                }
                RegCloseKey(hApp);
            }
            index++;
            nameLen = 256;
        }
        RegCloseKey(hKey);
    };

    dumpKey(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall");
    dumpKey(HKEY_LOCAL_MACHINE, L"SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall");
    dumpKey(HKEY_CURRENT_USER, L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall");

    if (fcsv) fclose(fcsv);
    if (ftxt) fclose(ftxt);
}

static std::vector<std::wstring> SplitCsvLine(const std::wstring& line) {
    std::vector<std::wstring> out;
    std::wstring cur;
    bool inQuotes = false;
    for (size_t i = 0; i < line.size(); ++i) {
        wchar_t c = line[i];
        if (c == L'"') {
            if (inQuotes && i + 1 < line.size() && line[i + 1] == L'"') {
                cur.push_back(L'"');
                ++i;
            } else {
                inQuotes = !inQuotes;
            }
            continue;
        }
        if (c == L';' && !inQuotes) {
            out.push_back(cur);
            cur.clear();
            continue;
        }
        if (c != L'\r' && c != L'\n') {
            cur.push_back(c);
        }
    }
    out.push_back(cur);
    return out;
}

static std::wstring NormalizeKey(const std::wstring& s) {
    std::wstring out;
    out.reserve(s.size());
    for (wchar_t c : s) {
        if (iswalnum(c)) {
            out.push_back(static_cast<wchar_t>(towlower(c)));
        }
    }
    return out;
}

static void CollectInstallerFiles(const std::wstring& root, std::vector<std::wstring>& files) {
    if (root.empty()) return;
    std::wstring pattern = PathJoin(root, L"*");
    WIN32_FIND_DATAW ffd{};
    HANDLE hFind = FindFirstFileW(pattern.c_str(), &ffd);
    if (hFind == INVALID_HANDLE_VALUE) return;
    do {
        if (wcscmp(ffd.cFileName, L".") == 0 || wcscmp(ffd.cFileName, L"..") == 0) continue;
        std::wstring item = PathJoin(root, ffd.cFileName);
        if (ffd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            CollectInstallerFiles(item, files);
        } else {
            std::wstring ext = PathFindExtensionW(item.c_str());
            std::transform(ext.begin(), ext.end(), ext.begin(), ::towlower);
            if (ext == L".exe" || ext == L".msi") {
                files.push_back(item);
            }
        }
    } while (FindNextFileW(hFind, &ffd));
    FindClose(hFind);
}

static std::wstring FindBestInstallerMatch(const std::wstring& appName, const std::vector<std::wstring>& installers) {
    std::wstring key = NormalizeKey(appName);
    if (key.empty()) return L"";
    std::wstring best;
    size_t bestScore = 0;
    for (const auto& path : installers) {
        wchar_t buf[MAX_PATH];
        lstrcpynW(buf, path.c_str(), MAX_PATH);
        PathStripPathW(buf);
        PathRemoveExtensionW(buf);
        std::wstring fkey = NormalizeKey(buf);
        if (fkey.empty()) continue;
        if (fkey.find(key) != std::wstring::npos || key.find(fkey) != std::wstring::npos) {
            size_t score = (fkey.size() < key.size()) ? fkey.size() : key.size();
            if (score > bestScore) {
                bestScore = score;
                best = path;
            }
        }
    }
    return best;
}

static bool RunSilentInstaller(const std::wstring& installerPath, const std::wstring& baseArgs, const std::wstring& label, std::wstring& error) {
    std::wstring ext = PathFindExtensionW(installerPath.c_str());
    std::transform(ext.begin(), ext.end(), ext.begin(), ::towlower);
    DWORD exitCode = 0;
    if (ext == L".msi") {
        std::wstring args = L"/i " + QuoteIfNeeded(installerPath) + L" /qn /norestart";
        if (!baseArgs.empty()) {
            args += L" ";
            args += baseArgs;
        }
        if (!RunProcess(L"msiexec.exe", args, exitCode)) {
            error = L"msiexec failed: " + std::to_wstring(exitCode);
            return false;
        }
        if (!ExitCodeSuccess(exitCode)) {
            error = L"msiexec exit: " + std::to_wstring(exitCode);
            return false;
        }
        return true;
    }

    std::vector<std::wstring> candidates;
    if (!baseArgs.empty()) {
        candidates.push_back(baseArgs);
    }
    auto addUnique = [&](const std::wstring& val) {
        if (std::find(candidates.begin(), candidates.end(), val) == candidates.end()) {
            candidates.push_back(val);
        }
    };
    addUnique(L"/S");
    addUnique(L"/s");
    addUnique(L"/silent");
    addUnique(L"/SILENT");
    addUnique(L"/verysilent");
    addUnique(L"/VERYSILENT");
    addUnique(L"/quiet");
    addUnique(L"/qn");
    addUnique(L"/s /quiet");
    addUnique(L"/S /quiet");
    addUnique(L"/s /silent");
    addUnique(L"/S /silent");
    addUnique(L"/quiet /norestart");
    addUnique(L"/passive /norestart");
    addUnique(L"/S /norestart");
    addUnique(L"/s /norestart");
    addUnique(L"/VERYSILENT /SUPPRESSMSGBOXES /NORESTART");
    addUnique(L"/SILENT /NORESTART");
    addUnique(L"/s /v\"/qn /norestart\"");
    addUnique(L"/S /v\"/qn /norestart\"");
    addUnique(L"/v\"/qn /norestart\"");
    addUnique(L"/s /v\"/qn\"");
    addUnique(L"/S /v\"/qn\"");
    addUnique(L"/s /v\"/quiet /norestart\"");
    addUnique(L"/S /v\"/quiet /norestart\"");

    for (const auto& cand : candidates) {
        AppendLog(L"  " + label + L" args: " + cand);
        if (!RunProcess(installerPath, cand, exitCode)) {
            continue;
        }
        if (ExitCodeSuccess(exitCode)) {
            return true;
        }
    }
    error = L"silent args failed";
    return false;
}

static bool IsProgramInstalled(const std::wstring& name) {
    if (name.empty()) return false;
    std::wstring key = NormalizeKey(name);
    auto checkKey = [&](HKEY root, const wchar_t* sub) -> bool {
        HKEY hKey = nullptr;
        if (RegOpenKeyExW(root, sub, 0, KEY_READ, &hKey) != ERROR_SUCCESS) {
            return false;
        }
        DWORD index = 0;
        wchar_t nameBuf[256];
        DWORD nameLen = 256;
        bool found = false;
        while (!found && RegEnumKeyExW(hKey, index, nameBuf, &nameLen, nullptr, nullptr, nullptr, nullptr) == ERROR_SUCCESS) {
            HKEY hApp = nullptr;
            if (RegOpenKeyExW(hKey, nameBuf, 0, KEY_READ, &hApp) == ERROR_SUCCESS) {
                wchar_t disp[512] = L"";
                DWORD sz = sizeof(disp);
                if (RegQueryValueExW(hApp, L"DisplayName", nullptr, nullptr, reinterpret_cast<LPBYTE>(disp), &sz) == ERROR_SUCCESS) {
                    std::wstring dkey = NormalizeKey(disp);
                    if (!dkey.empty() && (dkey.find(key) != std::wstring::npos || key.find(dkey) != std::wstring::npos)) {
                        found = true;
                    }
                }
                RegCloseKey(hApp);
            }
            index++;
            nameLen = 256;
        }
        RegCloseKey(hKey);
        return found;
    };
    if (checkKey(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall")) return true;
    if (checkKey(HKEY_LOCAL_MACHINE, L"SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall")) return true;
    if (checkKey(HKEY_CURRENT_USER, L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall")) return true;
    return false;
}

static std::wstring FindExeInPath(const std::wstring& exe) {
    wchar_t buf[MAX_PATH] = L"";
    if (SearchPathW(nullptr, exe.c_str(), nullptr, MAX_PATH, buf, nullptr) > 0) {
        return std::wstring(buf);
    }
    return L"";
}

static bool IsWingetAvailable() {
    return !FindExeInPath(L"winget.exe").empty();
}

static bool RunWingetInstallByName(const std::wstring& name, std::wstring& error) {
    std::wstring winget = FindExeInPath(L"winget.exe");
    if (winget.empty()) {
        error = L"winget.exe nicht gefunden";
        return false;
    }
    std::wstring args = L"install --name " + QuoteIfNeeded(name) + L" --silent --accept-source-agreements --accept-package-agreements --source winget --disable-interactivity";
    DWORD exitCode = 0;
    if (!RunProcess(winget, args, exitCode)) {
        error = L"winget failed: " + std::to_wstring(exitCode);
        return false;
    }
    if (!ExitCodeSuccess(exitCode)) {
        error = L"winget exit: " + std::to_wstring(exitCode);
        return false;
    }
    return true;
}

static void BackupMigration() {
    std::wstring root = Trim(GetEditText(g_hMigrationPath));
    if (root.empty()) {
        MessageBoxW(g_hWnd, L"Bitte einen Backup-Ordner angeben.", kAppTitle, MB_ICONWARNING);
        return;
    }
    if (!EnsureDirExists(root)) {
        MessageBoxW(g_hWnd, L"Backup-Ordner konnte nicht erstellt werden.", kAppTitle, MB_ICONERROR);
        return;
    }

    std::vector<int> sel;
    for (int i = 0; i < static_cast<int>(g_migrationItems.size()); ++i) {
        if (ListView_GetCheckState(g_hMigrationList, i)) sel.push_back(i);
    }
    if (sel.empty()) {
        MessageBoxW(g_hWnd, L"Bitte mindestens ein Item auswaehlen.", kAppTitle, MB_ICONWARNING);
        return;
    }

    AppendLog(L"Migrations-Backup gestartet...");
    for (int idx : sel) {
        const auto& item = g_migrationItems[idx];
        if (item.kind == MigrationKind::Programs) {
            AppendLog(L"  Programmliste exportieren...");
            ExportInstalledPrograms(PathJoin(root, L"Programs"));
            AppendLog(L"  Programmliste OK.");
            continue;
        }

        if (item.kind == MigrationKind::Thunderbird) {
            if (item.path.empty() || !PathFileExistsW(item.path.c_str())) {
                AppendLog(L"  Thunderbird nicht gefunden.");
                continue;
            }
            std::wstring dest = GetMigrationBackupPath(item, root);
            EnsureDirExists(PathJoin(root, L"Email"));
            if (PathFileExistsW(dest.c_str())) {
                if (MessageBoxW(g_hWnd, L"Thunderbird-Backup existiert. Ersetzen?", kAppTitle, MB_ICONQUESTION | MB_YESNO) != IDYES) {
                    continue;
                }
                DeleteDirectoryRecursive(dest);
            }
            int copied = 0;
            int failed = 0;
            CopyDirectoryRecursive(item.path, dest, true, copied, failed);
            AppendLog(L"  Thunderbird: " + std::to_wstring(copied) + L" Dateien, " + std::to_wstring(failed) + L" Fehler");
            continue;
        }

        if (item.kind == MigrationKind::Outlook) {
            std::wstring doc = GetKnownFolderPath(FOLDERID_Documents);
            std::wstring local = GetLocalAppData();
            std::wstring p1 = doc.empty() ? L"" : PathJoin(doc, L"Outlook Files");
            std::wstring p2 = local.empty() ? L"" : PathJoin(local, L"Microsoft\\Outlook");
            if ((p1.empty() || !PathFileExistsW(p1.c_str())) && (p2.empty() || !PathFileExistsW(p2.c_str()))) {
                AppendLog(L"  Outlook nicht gefunden.");
                continue;
            }
            std::wstring destBase = GetMigrationBackupPath(item, root);
            EnsureDirExists(PathJoin(root, L"Email"));
            EnsureDirExists(destBase);
            if (!p1.empty() && PathFileExistsW(p1.c_str())) {
                std::wstring dest = PathJoin(destBase, L"Documents");
                int copied = 0;
                int failed = 0;
                CopyDirectoryRecursive(p1, dest, true, copied, failed);
                AppendLog(L"  Outlook (Dokumente): " + std::to_wstring(copied) + L" Dateien, " + std::to_wstring(failed) + L" Fehler");
            }
            if (!p2.empty() && PathFileExistsW(p2.c_str())) {
                std::wstring dest = PathJoin(destBase, L"Local");
                int copied = 0;
                int failed = 0;
                CopyDirectoryRecursive(p2, dest, true, copied, failed);
                AppendLog(L"  Outlook (Local): " + std::to_wstring(copied) + L" Dateien, " + std::to_wstring(failed) + L" Fehler");
            }
            continue;
        }

        if (item.path.empty() || !PathFileExistsW(item.path.c_str())) {
            AppendLog(L"  Skip (nicht gefunden): " + item.name);
            continue;
        }
        std::wstring dest = GetMigrationBackupPath(item, root);
        EnsureDirExists(PathJoin(root, L"UserData"));
        if (PathFileExistsW(dest.c_str())) {
            std::wstring msg = item.name + L" Backup existiert. Ersetzen?";
            int res = MessageBoxW(g_hWnd, msg.c_str(), kAppTitle, MB_ICONQUESTION | MB_YESNOCANCEL);
            if (res == IDCANCEL) {
                AppendLog(L"Migrations-Backup abgebrochen.");
                return;
            }
            if (res == IDYES) {
                DeleteDirectoryRecursive(dest);
            } else {
                continue;
            }
        }
        int copied = 0;
        int failed = 0;
        CopyDirectoryRecursive(item.path, dest, true, copied, failed);
        AppendLog(L"  " + item.name + L": " + std::to_wstring(copied) + L" Dateien, " + std::to_wstring(failed) + L" Fehler");
    }

    AppendLog(L"Migrations-Backup abgeschlossen.");
    MessageBoxW(g_hWnd, L"Migrations-Backup abgeschlossen.", kAppTitle, MB_ICONINFORMATION);
    UpdateMigrationBackupStatus();
}

static void RestoreMigration() {
    std::wstring root = Trim(GetEditText(g_hMigrationPath));
    if (root.empty()) {
        MessageBoxW(g_hWnd, L"Bitte einen Backup-Ordner angeben.", kAppTitle, MB_ICONWARNING);
        return;
    }
    if (MessageBoxW(g_hWnd, L"Restore kopiert Daten und ueberschreibt gleichnamige Dateien. Fortfahren?", kAppTitle,
        MB_ICONWARNING | MB_YESNO) != IDYES) {
        return;
    }

    std::vector<int> sel;
    for (int i = 0; i < static_cast<int>(g_migrationItems.size()); ++i) {
        if (ListView_GetCheckState(g_hMigrationList, i)) sel.push_back(i);
    }
    if (sel.empty()) {
        MessageBoxW(g_hWnd, L"Bitte mindestens ein Item auswaehlen.", kAppTitle, MB_ICONWARNING);
        return;
    }

    AppendLog(L"Migrations-Restore gestartet...");
    for (int idx : sel) {
        const auto& item = g_migrationItems[idx];
        if (item.kind == MigrationKind::Programs) {
            std::wstring src = GetMigrationBackupPath(item, root);
            if (!PathFileExistsW(src.c_str())) {
                AppendLog(L"  Programmliste fehlt.");
                continue;
            }
            std::wstring docs = GetKnownFolderPath(FOLDERID_Documents);
            if (docs.empty()) {
                AppendLog(L"  Dokumente-Pfad fehlt.");
                continue;
            }
            std::wstring destDir = PathJoin(docs, L"BloatRemover");
            EnsureDirExists(destDir);
            CopyFileW(src.c_str(), PathJoin(destDir, L"InstalledPrograms.csv").c_str(), FALSE);
            std::wstring txtSrc = PathJoin(PathJoin(root, L"Programs"), L"InstalledPrograms.txt");
            if (PathFileExistsW(txtSrc.c_str())) {
                CopyFileW(txtSrc.c_str(), PathJoin(destDir, L"InstalledPrograms.txt").c_str(), FALSE);
            }
            AppendLog(L"  Programmliste nach Dokumente\\BloatRemover kopiert.");

            std::wstring installerRoot = Trim(GetEditText(g_hMigrationInstallerPath));
            std::vector<std::wstring> installers;
            if (!installerRoot.empty() && PathFileExistsW(installerRoot.c_str())) {
                AppendLog(L"  Suche lokale Installer...");
                CollectInstallerFiles(installerRoot, installers);
                AppendLog(L"  Gefundene Installer: " + std::to_wstring(installers.size()));
            }
            if (installers.empty()) {
                std::wstring downloads = GetKnownFolderPath(FOLDERID_Downloads);
                if (!downloads.empty() && PathFileExistsW(downloads.c_str())) {
                    AppendLog(L"  Keine Installer im Ordner. Durchsuche Downloads...");
                    CollectInstallerFiles(downloads, installers);
                    AppendLog(L"  Gefundene Installer (Downloads): " + std::to_wstring(installers.size()));
                }
            }

            std::wstring reportDir = PathJoin(root, L"Programs");
            EnsureDirExists(reportDir);
            std::wstring reportPath = PathJoin(reportDir, L"InstallReport.txt");
            FILE* frep = nullptr;
            _wfopen_s(&frep, reportPath.c_str(), L"w, ccs=UTF-8");
            if (frep) {
                fputws(L"InstallReport\r\n", frep);
                fputws(L"==========\r\n", frep);
            }

            bool useWinget = false;
            if (installers.empty()) {
                AppendLog(L"  Keine lokalen Installer gefunden.");
                if (IsWingetAvailable()) {
                    if (MessageBoxW(g_hWnd, L"Keine lokalen Installer gefunden. Programme ueber Internet (winget) suchen?", kAppTitle,
                        MB_ICONQUESTION | MB_YESNO) == IDYES) {
                        useWinget = true;
                        AppendLog(L"  Winget-Installation aktiviert.");
                    } else {
                        AppendLog(L"  Winget-Installation abgelehnt.");
                    }
                } else {
                    AppendLog(L"  Winget nicht verfuegbar.");
                }
            }

            if (installers.empty() && !useWinget) {
                if (frep) {
                    fputws(L"SKIP: Keine lokalen Installer gefunden und Winget nicht genutzt.\r\n", frep);
                }
            } else {
                FILE* fcsv = nullptr;
                _wfopen_s(&fcsv, src.c_str(), L"r, ccs=UTF-8");
                if (!fcsv) {
                    AppendLog(L"  Programmliste konnte nicht gelesen werden.");
                    if (frep) fputws(L"FAIL: Programmliste nicht lesbar.\r\n", frep);
                } else {
                    wchar_t line[2048];
                    bool first = true;
                    while (fgetws(line, 2048, fcsv)) {
                        std::wstring l = line;
                        if (first) {
                            first = false;
                            continue;
                        }
                        auto cols = SplitCsvLine(l);
                        if (cols.empty()) continue;
                        std::wstring name = Trim(cols[0]);
                        if (name.empty()) continue;

                        if (IsProgramInstalled(name)) {
                            if (frep) fwprintf(frep, L"SKIP (bereits installiert): %s\r\n", name.c_str());
                            continue;
                        }

                        if (!installers.empty()) {
                            std::wstring match = FindBestInstallerMatch(name, installers);
                            if (match.empty()) {
                                if (frep) fwprintf(frep, L"NOT FOUND (lokal): %s\r\n", name.c_str());
                                continue;
                            }

                            std::wstring err;
                            std::wstring label = L"Install " + name;
                            bool ok = RunSilentInstaller(match, L"", label, err);
                            if (ok) {
                                if (frep) fwprintf(frep, L"OK: %s -> %s\r\n", name.c_str(), match.c_str());
                            } else {
                                if (frep) fwprintf(frep, L"FAIL: %s -> %s (%s)\r\n", name.c_str(), match.c_str(), err.c_str());
                            }
                        } else if (useWinget) {
                            std::wstring err;
                            bool ok = RunWingetInstallByName(name, err);
                            if (ok) {
                                if (frep) fwprintf(frep, L"OK (winget): %s\r\n", name.c_str());
                            } else {
                                if (frep) fwprintf(frep, L"FAIL (winget): %s (%s)\r\n", name.c_str(), err.c_str());
                            }
                        }
                    }
                    fclose(fcsv);
                }
            }
            if (frep) {
                fclose(frep);
                AppendLog(L"  InstallReport: " + reportPath);
            }
            continue;
        }

        if (item.kind == MigrationKind::Thunderbird) {
            std::wstring src = GetMigrationBackupPath(item, root);
            if (!PathFileExistsW(src.c_str())) {
                AppendLog(L"  Thunderbird-Backup fehlt.");
                continue;
            }
            if (item.path.empty()) {
                AppendLog(L"  Thunderbird-Zielpfad fehlt.");
                continue;
            }
            EnsureDirExists(item.path);
            int copied = 0;
            int failed = 0;
            CopyDirectoryRecursive(src, item.path, true, copied, failed);
            AppendLog(L"  Thunderbird: " + std::to_wstring(copied) + L" Dateien, " + std::to_wstring(failed) + L" Fehler");
            continue;
        }

        if (item.kind == MigrationKind::Outlook) {
            std::wstring srcBase = GetMigrationBackupPath(item, root);
            if (!PathFileExistsW(srcBase.c_str())) {
                AppendLog(L"  Outlook-Backup fehlt.");
                continue;
            }
            std::wstring doc = GetKnownFolderPath(FOLDERID_Documents);
            std::wstring local = GetLocalAppData();
            std::wstring p1 = doc.empty() ? L"" : PathJoin(doc, L"Outlook Files");
            std::wstring p2 = local.empty() ? L"" : PathJoin(local, L"Microsoft\\Outlook");
            std::wstring srcDoc = PathJoin(srcBase, L"Documents");
            std::wstring srcLocal = PathJoin(srcBase, L"Local");
            if (!p1.empty() && PathFileExistsW(srcDoc.c_str())) {
                EnsureDirExists(p1);
                int copied = 0;
                int failed = 0;
                CopyDirectoryRecursive(srcDoc, p1, true, copied, failed);
                AppendLog(L"  Outlook (Dokumente): " + std::to_wstring(copied) + L" Dateien, " + std::to_wstring(failed) + L" Fehler");
            }
            if (!p2.empty() && PathFileExistsW(srcLocal.c_str())) {
                EnsureDirExists(p2);
                int copied = 0;
                int failed = 0;
                CopyDirectoryRecursive(srcLocal, p2, true, copied, failed);
                AppendLog(L"  Outlook (Local): " + std::to_wstring(copied) + L" Dateien, " + std::to_wstring(failed) + L" Fehler");
            }
            continue;
        }

        std::wstring src = GetMigrationBackupPath(item, root);
        if (src.empty() || !PathFileExistsW(src.c_str())) {
            AppendLog(L"  Backup fehlt: " + item.name);
            continue;
        }
        if (item.path.empty()) {
            AppendLog(L"  Zielpfad fehlt: " + item.name);
            continue;
        }
        EnsureDirExists(item.path);
        int copied = 0;
        int failed = 0;
        CopyDirectoryRecursive(src, item.path, true, copied, failed);
        AppendLog(L"  " + item.name + L": " + std::to_wstring(copied) + L" Dateien, " + std::to_wstring(failed) + L" Fehler");
    }

    AppendLog(L"Migrations-Restore abgeschlossen.");
    MessageBoxW(g_hWnd, L"Migrations-Restore abgeschlossen.", kAppTitle, MB_ICONINFORMATION);
    UpdateMigrationBackupStatus();
}

static bool BackupDpapiKeys(const std::wstring& backupRoot) {
    std::wstring sid = GetCurrentUserSid();
    if (sid.empty()) {
        AppendLog(L"  DPAPI: SID nicht ermittelbar.");
        return false;
    }

    std::wstring dpapiRoot = PathJoin(backupRoot, L"DPAPI");
    EnsureDirExists(dpapiRoot);
    std::wstring iniPath = PathJoin(dpapiRoot, L"dpapi.ini");
    WritePrivateProfileStringW(L"Meta", L"Version", L"1", iniPath.c_str());
    WritePrivateProfileStringW(L"Meta", L"Sid", sid.c_str(), iniPath.c_str());

    std::wstring roaming = GetRoamingAppData();
    std::wstring local = GetLocalAppData();
    bool ok = true;
    int copied = 0;
    int failed = 0;

    std::wstring srcProtect = PathJoin(PathJoin(roaming, L"Microsoft\\Protect"), sid);
    if (PathFileExistsW(srcProtect.c_str())) {
        copied = failed = 0;
        std::wstring dstProtect = PathJoin(PathJoin(dpapiRoot, L"Roaming\\Protect"), sid);
        CopyDirectoryRecursive(srcProtect, dstProtect, true, copied, failed);
        if (failed > 0) ok = false;
    }

    std::wstring srcCredRoam = PathJoin(roaming, L"Microsoft\\Credentials");
    if (PathFileExistsW(srcCredRoam.c_str())) {
        copied = failed = 0;
        std::wstring dstCredRoam = PathJoin(dpapiRoot, L"Roaming\\Credentials");
        CopyDirectoryRecursive(srcCredRoam, dstCredRoam, true, copied, failed);
        if (failed > 0) ok = false;
    }

    std::wstring srcCredLocal = PathJoin(local, L"Microsoft\\Credentials");
    if (PathFileExistsW(srcCredLocal.c_str())) {
        copied = failed = 0;
        std::wstring dstCredLocal = PathJoin(dpapiRoot, L"Local\\Credentials");
        CopyDirectoryRecursive(srcCredLocal, dstCredLocal, true, copied, failed);
        if (failed > 0) ok = false;
    }

    std::wstring srcProtectLocal = PathJoin(PathJoin(local, L"Microsoft\\Protect"), sid);
    if (PathFileExistsW(srcProtectLocal.c_str())) {
        copied = failed = 0;
        std::wstring dstProtectLocal = PathJoin(PathJoin(dpapiRoot, L"Local\\Protect"), sid);
        CopyDirectoryRecursive(srcProtectLocal, dstProtectLocal, true, copied, failed);
        if (failed > 0) ok = false;
    }

    return ok;
}

static bool RestoreDpapiKeys(const std::wstring& backupRoot) {
    std::wstring dpapiRoot = PathJoin(backupRoot, L"DPAPI");
    std::wstring iniPath = PathJoin(dpapiRoot, L"dpapi.ini");
    if (!PathFileExistsW(iniPath.c_str())) {
        AppendLog(L"  DPAPI: Kein Backup gefunden.");
        return false;
    }

    std::wstring backupSid = GetIniString(L"Meta", L"Sid", L"", iniPath);
    std::wstring currentSid = GetCurrentUserSid();
    if (backupSid.empty() && currentSid.empty()) {
        AppendLog(L"  DPAPI: SID fehlt.");
        return false;
    }
    if (!backupSid.empty() && !currentSid.empty() && ToLower(backupSid) != ToLower(currentSid)) {
        std::wstring msg = L"DPAPI-SID passt nicht zum aktuellen Benutzer.\r\n";
        msg += L"Backup SID: " + backupSid + L"\r\n";
        msg += L"Aktuell SID: " + currentSid + L"\r\n";
        msg += L"Trotzdem fortfahren?";
        if (MessageBoxW(g_hWnd, msg.c_str(), kAppTitle, MB_ICONWARNING | MB_YESNO) != IDYES) {
            return false;
        }
    }

    std::wstring roaming = GetRoamingAppData();
    std::wstring local = GetLocalAppData();
    bool ok = true;
    int copied = 0;
    int failed = 0;

    std::wstring srcProtect = PathJoin(PathJoin(dpapiRoot, L"Roaming\\Protect"), backupSid.empty() ? currentSid : backupSid);
    if (PathFileExistsW(srcProtect.c_str())) {
        copied = failed = 0;
        std::wstring dstProtect = PathJoin(PathJoin(roaming, L"Microsoft\\Protect"), currentSid.empty() ? backupSid : currentSid);
        CopyDirectoryRecursive(srcProtect, dstProtect, true, copied, failed);
        if (failed > 0) ok = false;
    }

    std::wstring srcCredRoam = PathJoin(dpapiRoot, L"Roaming\\Credentials");
    if (PathFileExistsW(srcCredRoam.c_str())) {
        copied = failed = 0;
        std::wstring dstCredRoam = PathJoin(roaming, L"Microsoft\\Credentials");
        CopyDirectoryRecursive(srcCredRoam, dstCredRoam, true, copied, failed);
        if (failed > 0) ok = false;
    }

    std::wstring srcCredLocal = PathJoin(dpapiRoot, L"Local\\Credentials");
    if (PathFileExistsW(srcCredLocal.c_str())) {
        copied = failed = 0;
        std::wstring dstCredLocal = PathJoin(local, L"Microsoft\\Credentials");
        CopyDirectoryRecursive(srcCredLocal, dstCredLocal, true, copied, failed);
        if (failed > 0) ok = false;
    }

    std::wstring srcProtectLocal = PathJoin(PathJoin(dpapiRoot, L"Local\\Protect"), backupSid.empty() ? currentSid : backupSid);
    if (PathFileExistsW(srcProtectLocal.c_str())) {
        copied = failed = 0;
        std::wstring dstProtectLocal = PathJoin(PathJoin(local, L"Microsoft\\Protect"), currentSid.empty() ? backupSid : currentSid);
        CopyDirectoryRecursive(srcProtectLocal, dstProtectLocal, true, copied, failed);
        if (failed > 0) ok = false;
    }

    return ok;
}

static void BackupBrowsers() {
    std::wstring root = Trim(GetEditText(g_hBrowserPath));
    if (root.empty()) {
        MessageBoxW(g_hWnd, L"Bitte einen Backup-Ordner angeben.", kAppTitle, MB_ICONWARNING);
        return;
    }
    if (!EnsureDirExists(root)) {
        MessageBoxW(g_hWnd, L"Backup-Ordner konnte nicht erstellt werden.", kAppTitle, MB_ICONERROR);
        return;
    }

    std::vector<int> sel;
    for (int i = 0; i < static_cast<int>(g_browsers.size()); ++i) {
        if (ListView_GetCheckState(g_hBrowserList, i)) sel.push_back(i);
    }
    if (sel.empty()) {
        MessageBoxW(g_hWnd, L"Bitte mindestens einen Browser auswaehlen.", kAppTitle, MB_ICONWARNING);
        return;
    }

    std::wstring browsersRoot = PathJoin(root, L"Browsers");
    EnsureDirExists(browsersRoot);

    AppendLog(L"Browser-Backup gestartet...");
    for (int idx : sel) {
        const auto& b = g_browsers[idx];
        if (!PathFileExistsW(b.path.c_str())) {
            AppendLog(L"  Skip (nicht gefunden): " + b.name);
            continue;
        }
        std::wstring dest = PathJoin(browsersRoot, b.id);
        if (PathFileExistsW(dest.c_str())) {
            std::wstring msg = L"Backup fuer " + b.name + L" existiert bereits. Ersetzen?";
            int res = MessageBoxW(g_hWnd, msg.c_str(), kAppTitle, MB_ICONQUESTION | MB_YESNOCANCEL);
            if (res == IDCANCEL) {
                AppendLog(L"Browser-Backup abgebrochen.");
                return;
            }
            if (res == IDYES) {
                if (!DeleteDirectoryRecursive(dest)) {
                    AppendLog(L"  Warnung: Konnte altes Backup nicht loeschen.");
                }
            }
        }
        int copied = 0;
        int failed = 0;
        CopyDirectoryRecursive(b.path, dest, true, copied, failed);
        AppendLog(L"  " + b.name + L": " + std::to_wstring(copied) + L" Dateien, " + std::to_wstring(failed) + L" Fehler");
    }

    if (IsChecked(g_hChkBrowserDpapi)) {
        AppendLog(L"DPAPI-Keys sichern...");
        if (BackupDpapiKeys(root)) {
            AppendLog(L"  DPAPI-Backup OK.");
        } else {
            AppendLog(L"  DPAPI-Backup mit Fehlern.");
        }
    }

    AppendLog(L"Browser-Backup abgeschlossen.");
    MessageBoxW(g_hWnd, L"Browser-Backup abgeschlossen.", kAppTitle, MB_ICONINFORMATION);
    UpdateBrowserBackupStatus();
}

static void RestoreBrowsers() {
    std::wstring root = Trim(GetEditText(g_hBrowserPath));
    if (root.empty()) {
        MessageBoxW(g_hWnd, L"Bitte einen Backup-Ordner angeben.", kAppTitle, MB_ICONWARNING);
        return;
    }

    std::wstring browsersRoot = PathJoin(root, L"Browsers");
    if (!PathFileExistsW(browsersRoot.c_str())) {
        MessageBoxW(g_hWnd, L"Kein Browser-Backup im angegebenen Ordner gefunden.", kAppTitle, MB_ICONERROR);
        return;
    }

    std::vector<int> sel;
    for (int i = 0; i < static_cast<int>(g_browsers.size()); ++i) {
        if (ListView_GetCheckState(g_hBrowserList, i)) sel.push_back(i);
    }
    if (sel.empty()) {
        MessageBoxW(g_hWnd, L"Bitte mindestens einen Browser auswaehlen.", kAppTitle, MB_ICONWARNING);
        return;
    }

    if (MessageBoxW(g_hWnd, L"Restore ueberschreibt vorhandene Browser-Profile. Fortfahren?", kAppTitle,
        MB_ICONWARNING | MB_YESNO) != IDYES) {
        return;
    }

    AppendLog(L"Browser-Restore gestartet...");
    for (int idx : sel) {
        const auto& b = g_browsers[idx];
        std::wstring src = PathJoin(browsersRoot, b.id);
        if (!PathFileExistsW(src.c_str())) {
            AppendLog(L"  Backup fehlt: " + b.name);
            continue;
        }
        if (PathFileExistsW(b.path.c_str())) {
            if (!DeleteDirectoryRecursive(b.path)) {
                AppendLog(L"  Warnung: Konnte vorhandenes Profil nicht loeschen: " + b.name);
            }
        }
        EnsureDirExists(b.path);
        int copied = 0;
        int failed = 0;
        CopyDirectoryRecursive(src, b.path, true, copied, failed);
        AppendLog(L"  " + b.name + L": " + std::to_wstring(copied) + L" Dateien, " + std::to_wstring(failed) + L" Fehler");
    }

    if (IsChecked(g_hChkBrowserDpapi)) {
        std::wstring warn = L"DPAPI-Keys werden wiederhergestellt.\r\n";
        warn += L"Das kann bestehende Windows-Credentials beeinflussen.\r\nFortfahren?";
        if (MessageBoxW(g_hWnd, warn.c_str(), kAppTitle, MB_ICONWARNING | MB_YESNO) == IDYES) {
            AppendLog(L"DPAPI-Keys restore...");
            if (RestoreDpapiKeys(root)) {
                AppendLog(L"  DPAPI-Restore OK.");
            } else {
                AppendLog(L"  DPAPI-Restore mit Fehlern.");
            }
        }
    }

    AppendLog(L"Browser-Restore abgeschlossen.");
    MessageBoxW(g_hWnd, L"Browser-Restore abgeschlossen.", kAppTitle, MB_ICONINFORMATION);
    UpdateBrowserBackupStatus();
}

static void LayoutControls() {
    RECT rc{};
    GetClientRect(g_hWnd, &rc);
    int padding = 12;
    int width = rc.right - rc.left;
    int x = padding;
    int y = padding;

    MoveWindow(g_hTab, x, y, width - 2 * padding, rc.bottom - rc.top - 2 * padding, TRUE);

    RECT tr{};
    GetClientRect(g_hTab, &tr);
    TabCtrl_AdjustRect(g_hTab, FALSE, &tr);
    int pageWidth = tr.right - tr.left;
    int pageHeight = tr.bottom - tr.top;
    MoveWindow(g_hPageInstall, tr.left, tr.top, pageWidth, pageHeight, TRUE);
    MoveWindow(g_hPageCustom, tr.left, tr.top, pageWidth, pageHeight, TRUE);
    MoveWindow(g_hPageSystem, tr.left, tr.top, pageWidth, pageHeight, TRUE);
    MoveWindow(g_hPageMigration, tr.left, tr.top, pageWidth, pageHeight, TRUE);
    MoveWindow(g_hPageBrowser, tr.left, tr.top, pageWidth, pageHeight, TRUE);
    MoveWindow(g_hPagePower, tr.left, tr.top, pageWidth, pageHeight, TRUE);
    MoveWindow(g_hPageConfig, tr.left, tr.top, pageWidth, pageHeight, TRUE);

    // Install page layout
    int ix = padding;
    int iy = padding;
    int iwidth = pageWidth;

    int listHeight = 220;
    int btnHeight = 28;
    int gap = 8;

    MoveWindow(g_hList, ix, iy, iwidth - 2 * padding, listHeight, TRUE);
    iy += listHeight + gap;

    int btnWidth = 140;
    MoveWindow(g_hBtnInstall, ix, iy, btnWidth, btnHeight, TRUE);
    MoveWindow(g_hBtnPreset, ix + btnWidth + gap, iy, btnWidth, btnHeight, TRUE);
    MoveWindow(g_hBtnSelectAll, ix + (btnWidth + gap) * 2, iy, btnWidth, btnHeight, TRUE);
    MoveWindow(g_hBtnClear, ix + (btnWidth + gap) * 3, iy, btnWidth, btnHeight, TRUE);
    MoveWindow(g_hBtnRunAll, ix + (btnWidth + gap) * 4, iy, btnWidth, btnHeight, TRUE);
    iy += btnHeight + gap;

    int labelHeight = 18;
    int editHeight = 24;
    int browseWidth = 90;
    int runWidth = 130;
    int rowHeight = 22;

    int logHeight = pageHeight - iy - padding;
    if (logHeight < 80) logHeight = 80;
    MoveWindow(g_hLog, ix, iy, iwidth - 2 * padding, logHeight, TRUE);

    // Custom page layout
    int cx = padding;
    int cy = padding;
    int cwidth = pageWidth;
    int listHeightCustom = 220;

    MoveWindow(g_hCustomList, cx, cy, cwidth - 2 * padding, listHeightCustom, TRUE);
    cy += listHeightCustom + gap;

    MoveWindow(g_hLblCustomName, cx, cy, 80, labelHeight, TRUE);
    MoveWindow(g_hCustomName, cx + 90, cy - 2, cwidth - 2 * padding - 90, editHeight, TRUE);
    cy += editHeight + gap;

    MoveWindow(g_hLblCustomPath, cx, cy, 80, labelHeight, TRUE);
    MoveWindow(g_hCustomPath, cx + 90, cy - 2, cwidth - 2 * padding - 90 - browseWidth - gap, editHeight, TRUE);
    MoveWindow(g_hBtnBrowse, cx + (cwidth - 2 * padding - browseWidth), cy - 2, browseWidth, editHeight, TRUE);
    cy += editHeight + gap;

    MoveWindow(g_hLblCustomArgs, cx, cy, 80, labelHeight, TRUE);
    MoveWindow(g_hCustomArgs, cx + 90, cy - 2, cwidth - 2 * padding - 90, editHeight, TRUE);
    cy += editHeight + gap;

    MoveWindow(g_hBtnCustomAdd, cx, cy, 120, btnHeight, TRUE);
    MoveWindow(g_hBtnCustomRemove, cx + 120 + gap, cy, 120, btnHeight, TRUE);
    MoveWindow(g_hBtnRunCustom, cx + (cwidth - 2 * padding - runWidth * 2 - gap), cy, runWidth, btnHeight, TRUE);
    MoveWindow(g_hBtnInstallAllCustom, cx + (cwidth - 2 * padding - runWidth), cy, runWidth, btnHeight, TRUE);

    // System page layout
    int sx = padding;
    int sy = padding;
    int swidth = pageWidth;
    int groupUsersHeight = 250;
    int groupJoinHeight = pageHeight - groupUsersHeight - padding - gap;
    if (groupJoinHeight < 200) groupJoinHeight = 200;

    MoveWindow(g_hGroupUsers, sx, sy, swidth - 2 * padding, groupUsersHeight, TRUE);
    int ux = sx + 12;
    int uy = sy + 22;
    int uwidth = swidth - 2 * padding - 24;
    int userListHeight = 140;
    MoveWindow(g_hUserList, ux, uy, uwidth, userListHeight, TRUE);
    uy += userListHeight + gap;
    MoveWindow(g_hLblUserName, ux, uy, 80, labelHeight, TRUE);
    MoveWindow(g_hUserName, ux + 90, uy - 2, uwidth - 90, editHeight, TRUE);
    uy += editHeight + gap;
    MoveWindow(g_hLblUserGroups, ux, uy, 80, labelHeight, TRUE);
    MoveWindow(g_hUserGroups, ux + 90, uy - 2, uwidth - 90, editHeight, TRUE);
    uy += editHeight + gap;
    MoveWindow(g_hBtnUserAdd, ux, uy, 110, btnHeight, TRUE);
    MoveWindow(g_hBtnUserRemove, ux + 110 + gap, uy, 110, btnHeight, TRUE);
    MoveWindow(g_hBtnUserCreate, ux + 220 + gap * 2, uy, 150, btnHeight, TRUE);

    sy += groupUsersHeight + gap;
    MoveWindow(g_hGroupJoin, sx, sy, swidth - 2 * padding, groupJoinHeight, TRUE);
    int jx = sx + 12;
    int jy = sy + 22;
    int jwidth = swidth - 2 * padding - 24;
    MoveWindow(g_hChkJoinEnable, jx, jy, jwidth, rowHeight, TRUE);
    jy += rowHeight + 4;
    MoveWindow(g_hRadioWorkgroup, jx, jy, 140, rowHeight, TRUE);
    MoveWindow(g_hRadioDomain, jx + 150, jy, 140, rowHeight, TRUE);
    jy += rowHeight + 6;
    MoveWindow(g_hLblJoinTarget, jx, jy, 110, labelHeight, TRUE);
    MoveWindow(g_hJoinTarget, jx + 120, jy - 2, jwidth - 120, editHeight, TRUE);
    jy += editHeight + gap;
    MoveWindow(g_hLblJoinHostname, jx, jy, 110, labelHeight, TRUE);
    MoveWindow(g_hJoinHostname, jx + 120, jy - 2, jwidth - 120, editHeight, TRUE);
    MoveWindow(g_hBtnJoinNow, jx + (jwidth - 140), sy + groupJoinHeight - btnHeight - 8, 140, btnHeight, TRUE);

    // Migration page layout
    int mx = padding;
    int my = padding;
    int mwidth = pageWidth;
    int mInfoHeight = labelHeight * 2 + 2;
    MoveWindow(g_hMigrationInfo, mx, my, mwidth - 2 * padding, mInfoHeight, TRUE);
    my += mInfoHeight + gap;

    int listHeightMigration = 220;
    MoveWindow(g_hMigrationList, mx, my, mwidth - 2 * padding, listHeightMigration, TRUE);
    my += listHeightMigration + gap;

    MoveWindow(g_hLblMigrationPath, mx, my, 90, labelHeight, TRUE);
    MoveWindow(g_hMigrationPath, mx + 100, my - 2, mwidth - 2 * padding - 100 - browseWidth - gap, editHeight, TRUE);
    MoveWindow(g_hBtnMigrationBrowse, mx + (mwidth - 2 * padding - browseWidth), my - 2, browseWidth, editHeight, TRUE);
    my += editHeight + gap;

    MoveWindow(g_hLblMigrationInstaller, mx, my, 110, labelHeight, TRUE);
    MoveWindow(g_hMigrationInstallerPath, mx + 120, my - 2, mwidth - 2 * padding - 120 - browseWidth - gap, editHeight, TRUE);
    MoveWindow(g_hBtnMigrationInstallerBrowse, mx + (mwidth - 2 * padding - browseWidth), my - 2, browseWidth, editHeight, TRUE);
    my += editHeight + gap;

    MoveWindow(g_hBtnMigrationSelectAll, mx, my, 100, btnHeight, TRUE);
    MoveWindow(g_hBtnMigrationClear, mx + 100 + gap, my, 100, btnHeight, TRUE);
    MoveWindow(g_hBtnMigrationBackup, mx + (mwidth - 2 * padding - runWidth * 2 - gap), my, runWidth, btnHeight, TRUE);
    MoveWindow(g_hBtnMigrationRestore, mx + (mwidth - 2 * padding - runWidth), my, runWidth, btnHeight, TRUE);

    // Browser page layout
    int bx = padding;
    int by = padding;
    int bwidth = pageWidth;
    int infoHeight = labelHeight * 2 + 2;
    MoveWindow(g_hBrowserInfo, bx, by, bwidth - 2 * padding, infoHeight, TRUE);
    by += infoHeight + gap;

    int listHeightBrowser = 220;
    MoveWindow(g_hBrowserList, bx, by, bwidth - 2 * padding, listHeightBrowser, TRUE);
    by += listHeightBrowser + gap;

    MoveWindow(g_hLblBrowserPath, bx, by, 90, labelHeight, TRUE);
    MoveWindow(g_hBrowserPath, bx + 100, by - 2, bwidth - 2 * padding - 100 - browseWidth - gap, editHeight, TRUE);
    MoveWindow(g_hBtnBrowserBrowse, bx + (bwidth - 2 * padding - browseWidth), by - 2, browseWidth, editHeight, TRUE);
    by += editHeight + gap;

    MoveWindow(g_hChkBrowserDpapi, bx, by, bwidth - 2 * padding, rowHeight, TRUE);
    by += rowHeight + gap;

    MoveWindow(g_hBtnBrowserSelectAll, bx, by, 100, btnHeight, TRUE);
    MoveWindow(g_hBtnBrowserClear, bx + 100 + gap, by, 100, btnHeight, TRUE);
    MoveWindow(g_hBtnBrowserBackup, bx + (bwidth - 2 * padding - runWidth * 2 - gap), by, runWidth, btnHeight, TRUE);
    MoveWindow(g_hBtnBrowserRestore, bx + (bwidth - 2 * padding - runWidth), by, runWidth, btnHeight, TRUE);

    // Power page layout
    int px = padding;
    int py = padding;
    int pwidth = pageWidth;
    int groupHeight = pageHeight - padding * 2;
    if (groupHeight < 200) groupHeight = 200;
    MoveWindow(g_hGroupPower, px, py, pwidth - 2 * padding, groupHeight, TRUE);

    int innerX = px + 12;
    int innerY = py + 22;
    int checkWidth = 260;
    int editWidth = 70;

    MoveWindow(g_hChkFastStartup, innerX, innerY, pwidth - 2 * padding - 24, rowHeight, TRUE);
    innerY += rowHeight + 4;

    MoveWindow(g_hChkHibernateAC, innerX, innerY, checkWidth, rowHeight, TRUE);
    MoveWindow(g_hEditHibernateAC, innerX + checkWidth + 8, innerY - 1, editWidth, editHeight, TRUE);
    innerY += rowHeight + 4;

    MoveWindow(g_hChkMonitorAC, innerX, innerY, checkWidth, rowHeight, TRUE);
    MoveWindow(g_hEditMonitorAC, innerX + checkWidth + 8, innerY - 1, editWidth, editHeight, TRUE);
    innerY += rowHeight + 4;

    MoveWindow(g_hChkSleepAC, innerX, innerY, checkWidth, rowHeight, TRUE);
    MoveWindow(g_hEditSleepAC, innerX + checkWidth + 8, innerY - 1, editWidth, editHeight, TRUE);
    innerY += rowHeight + 4;

    MoveWindow(g_hChkHibernateDC, innerX, innerY, checkWidth, rowHeight, TRUE);
    MoveWindow(g_hEditHibernateDC, innerX + checkWidth + 8, innerY - 1, editWidth, editHeight, TRUE);
    innerY += rowHeight + 4;

    MoveWindow(g_hChkMonitorDC, innerX, innerY, checkWidth, rowHeight, TRUE);
    MoveWindow(g_hEditMonitorDC, innerX + checkWidth + 8, innerY - 1, editWidth, editHeight, TRUE);

    MoveWindow(g_hBtnApplyPower, px + (pwidth - 2 * padding - 160), py + groupHeight - btnHeight - 8, 160, btnHeight, TRUE);

    // Config page layout
    int fx = padding;
    int fy = padding;
    int fwidth = pageWidth;
    MoveWindow(g_hConfigInfo, fx, fy, fwidth - 2 * padding, labelHeight, TRUE);
    fy += labelHeight + gap;
    MoveWindow(g_hLblConfigPath, fx, fy, 80, labelHeight, TRUE);
    MoveWindow(g_hConfigPath, fx + 90, fy - 2, fwidth - 2 * padding - 90 - browseWidth - gap, editHeight, TRUE);
    MoveWindow(g_hBtnConfigBrowse, fx + (fwidth - 2 * padding - browseWidth), fy - 2, browseWidth, editHeight, TRUE);
    fy += editHeight + gap;
    MoveWindow(g_hBtnConfigLoad, fx, fy, 120, btnHeight, TRUE);
    MoveWindow(g_hBtnConfigSave, fx + 120 + gap, fy, 120, btnHeight, TRUE);
}

static void InitListViewColumns() {
    LVCOLUMNW col{};
    col.mask = LVCF_TEXT | LVCF_WIDTH;
    col.pszText = const_cast<LPWSTR>(L"Installers");
    col.cx = 500;
    ListView_InsertColumn(g_hList, 0, &col);
}

static LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_CREATE: {
        g_hTab = CreateWindowExW(0, WC_TABCONTROLW, L"",
            WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS,
            0, 0, 0, 0, hWnd, (HMENU)ID_TAB, g_hInst, nullptr);

        TCITEMW tie{};
        tie.mask = TCIF_TEXT;
        tie.pszText = const_cast<LPWSTR>(L"Install");
        TabCtrl_InsertItem(g_hTab, 0, &tie);
        tie.pszText = const_cast<LPWSTR>(L"Custom");
        TabCtrl_InsertItem(g_hTab, 1, &tie);
        tie.pszText = const_cast<LPWSTR>(L"System");
        TabCtrl_InsertItem(g_hTab, 2, &tie);
        tie.pszText = const_cast<LPWSTR>(L"Migration");
        TabCtrl_InsertItem(g_hTab, 3, &tie);
        tie.pszText = const_cast<LPWSTR>(L"Browser");
        TabCtrl_InsertItem(g_hTab, 4, &tie);
        tie.pszText = const_cast<LPWSTR>(L"Energie");
        TabCtrl_InsertItem(g_hTab, 5, &tie);
        tie.pszText = const_cast<LPWSTR>(L"Config");
        TabCtrl_InsertItem(g_hTab, 6, &tie);
        TabCtrl_SetCurSel(g_hTab, 0);

        g_hPageInstall = CreateWindowW(kPageClass, L"", WS_CHILD | WS_VISIBLE,
            0, 0, 0, 0, g_hTab, nullptr, g_hInst, nullptr);
        g_hPageCustom = CreateWindowW(kPageClass, L"", WS_CHILD,
            0, 0, 0, 0, g_hTab, nullptr, g_hInst, nullptr);
        g_hPageSystem = CreateWindowW(kPageClass, L"", WS_CHILD,
            0, 0, 0, 0, g_hTab, nullptr, g_hInst, nullptr);
        g_hPageMigration = CreateWindowW(kPageClass, L"", WS_CHILD,
            0, 0, 0, 0, g_hTab, nullptr, g_hInst, nullptr);
        g_hPageBrowser = CreateWindowW(kPageClass, L"", WS_CHILD,
            0, 0, 0, 0, g_hTab, nullptr, g_hInst, nullptr);
        g_hPagePower = CreateWindowW(kPageClass, L"", WS_CHILD,
            0, 0, 0, 0, g_hTab, nullptr, g_hInst, nullptr);
        g_hPageConfig = CreateWindowW(kPageClass, L"", WS_CHILD,
            0, 0, 0, 0, g_hTab, nullptr, g_hInst, nullptr);

        g_hList = CreateWindowExW(WS_EX_CLIENTEDGE, WC_LISTVIEWW, L"",
            WS_CHILD | WS_VISIBLE | LVS_REPORT | LVS_SINGLESEL,
            0, 0, 0, 0, g_hPageInstall, (HMENU)ID_LIST, g_hInst, nullptr);
        ListView_SetExtendedListViewStyle(g_hList, LVS_EX_CHECKBOXES | LVS_EX_FULLROWSELECT);
        InitListViewColumns();

        g_hBtnInstall = CreateWindowW(L"BUTTON", L"Install Selected", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageInstall, (HMENU)ID_BTN_INSTALL, g_hInst, nullptr);
        g_hBtnPreset = CreateWindowW(L"BUTTON", L"Apply Preset", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageInstall, (HMENU)ID_BTN_PRESET, g_hInst, nullptr);
        g_hBtnSelectAll = CreateWindowW(L"BUTTON", L"Select All", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageInstall, (HMENU)ID_BTN_SELECT_ALL, g_hInst, nullptr);
        g_hBtnClear = CreateWindowW(L"BUTTON", L"Clear", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageInstall, (HMENU)ID_BTN_CLEAR, g_hInst, nullptr);
        g_hBtnRunAll = CreateWindowW(L"BUTTON", L"Run All", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageInstall, (HMENU)ID_BTN_RUN_ALL, g_hInst, nullptr);

        g_hLog = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
            WS_CHILD | WS_VISIBLE | ES_MULTILINE | ES_AUTOVSCROLL | ES_READONLY | WS_VSCROLL,
            0, 0, 0, 0, g_hPageInstall, (HMENU)ID_EDIT_LOG, g_hInst, nullptr);

        g_hCustomList = CreateWindowExW(WS_EX_CLIENTEDGE, WC_LISTVIEWW, L"",
            WS_CHILD | WS_VISIBLE | LVS_REPORT | LVS_SINGLESEL,
            0, 0, 0, 0, g_hPageCustom, (HMENU)ID_CUSTOM_LIST, g_hInst, nullptr);
        ListView_SetExtendedListViewStyle(g_hCustomList, LVS_EX_FULLROWSELECT);
        InitCustomListColumns();

        g_hLblCustomName = CreateWindowW(L"STATIC", L"Name", WS_CHILD | WS_VISIBLE,
            0, 0, 0, 0, g_hPageCustom, (HMENU)ID_LABEL_CUSTOM_NAME, g_hInst, nullptr);
        g_hCustomName = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
            WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
            0, 0, 0, 0, g_hPageCustom, (HMENU)ID_EDIT_CUSTOM_NAME, g_hInst, nullptr);
        g_hLblCustomPath = CreateWindowW(L"STATIC", L"Pfad", WS_CHILD | WS_VISIBLE,
            0, 0, 0, 0, g_hPageCustom, (HMENU)ID_LABEL_CUSTOM_PATH, g_hInst, nullptr);
        g_hCustomPath = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
            WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
            0, 0, 0, 0, g_hPageCustom, (HMENU)ID_EDIT_CUSTOM_PATH, g_hInst, nullptr);
        g_hBtnBrowse = CreateWindowW(L"BUTTON", L"Browse", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageCustom, (HMENU)ID_BTN_BROWSE, g_hInst, nullptr);
        g_hLblCustomArgs = CreateWindowW(L"STATIC", L"Args", WS_CHILD | WS_VISIBLE,
            0, 0, 0, 0, g_hPageCustom, (HMENU)ID_LABEL_CUSTOM_ARGS, g_hInst, nullptr);
        g_hCustomArgs = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
            WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
            0, 0, 0, 0, g_hPageCustom, (HMENU)ID_EDIT_CUSTOM_ARGS, g_hInst, nullptr);
        g_hBtnCustomAdd = CreateWindowW(L"BUTTON", L"Hinzufuegen", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageCustom, (HMENU)ID_BTN_CUSTOM_ADD, g_hInst, nullptr);
        g_hBtnCustomRemove = CreateWindowW(L"BUTTON", L"Entfernen", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageCustom, (HMENU)ID_BTN_CUSTOM_REMOVE, g_hInst, nullptr);
        g_hBtnRunCustom = CreateWindowW(L"BUTTON", L"Installieren", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageCustom, (HMENU)ID_BTN_RUN_CUSTOM, g_hInst, nullptr);
        g_hBtnInstallAllCustom = CreateWindowW(L"BUTTON", L"Alle installieren", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageCustom, (HMENU)ID_BTN_INSTALL_ALL_CUSTOM, g_hInst, nullptr);

        g_hGroupUsers = CreateWindowW(L"BUTTON", L"Lokale Benutzer", WS_CHILD | WS_VISIBLE | BS_GROUPBOX,
            0, 0, 0, 0, g_hPageSystem, nullptr, g_hInst, nullptr);
        g_hUserList = CreateWindowExW(WS_EX_CLIENTEDGE, WC_LISTVIEWW, L"",
            WS_CHILD | WS_VISIBLE | LVS_REPORT | LVS_SINGLESEL,
            0, 0, 0, 0, g_hPageSystem, (HMENU)ID_USER_LIST, g_hInst, nullptr);
        ListView_SetExtendedListViewStyle(g_hUserList, LVS_EX_FULLROWSELECT);
        InitUserListColumns();
        g_hLblUserName = CreateWindowW(L"STATIC", L"Name", WS_CHILD | WS_VISIBLE,
            0, 0, 0, 0, g_hPageSystem, (HMENU)ID_LABEL_USER_NAME, g_hInst, nullptr);
        g_hUserName = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
            WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
            0, 0, 0, 0, g_hPageSystem, (HMENU)ID_EDIT_USER_NAME, g_hInst, nullptr);
        g_hLblUserGroups = CreateWindowW(L"STATIC", L"Gruppen", WS_CHILD | WS_VISIBLE,
            0, 0, 0, 0, g_hPageSystem, (HMENU)ID_LABEL_USER_GROUPS, g_hInst, nullptr);
        g_hUserGroups = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
            WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
            0, 0, 0, 0, g_hPageSystem, (HMENU)ID_EDIT_USER_GROUPS, g_hInst, nullptr);
        g_hBtnUserAdd = CreateWindowW(L"BUTTON", L"Hinzufuegen", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageSystem, (HMENU)ID_BTN_USER_ADD, g_hInst, nullptr);
        g_hBtnUserRemove = CreateWindowW(L"BUTTON", L"Entfernen", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageSystem, (HMENU)ID_BTN_USER_REMOVE, g_hInst, nullptr);
        g_hBtnUserCreate = CreateWindowW(L"BUTTON", L"User erstellen", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageSystem, (HMENU)ID_BTN_USER_CREATE, g_hInst, nullptr);

        g_hGroupJoin = CreateWindowW(L"BUTTON", L"Domain / Workgroup", WS_CHILD | WS_VISIBLE | BS_GROUPBOX,
            0, 0, 0, 0, g_hPageSystem, (HMENU)ID_GROUP_JOIN, g_hInst, nullptr);
        g_hChkJoinEnable = CreateWindowW(L"BUTTON", L"Join aktivieren (beim Start fragen)", WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX,
            0, 0, 0, 0, g_hPageSystem, (HMENU)ID_CHK_JOIN_ENABLE, g_hInst, nullptr);
        g_hRadioWorkgroup = CreateWindowW(L"BUTTON", L"Workgroup", WS_CHILD | WS_VISIBLE | BS_AUTORADIOBUTTON,
            0, 0, 0, 0, g_hPageSystem, (HMENU)ID_RADIO_JOIN_WORKGROUP, g_hInst, nullptr);
        g_hRadioDomain = CreateWindowW(L"BUTTON", L"Domain", WS_CHILD | WS_VISIBLE | BS_AUTORADIOBUTTON,
            0, 0, 0, 0, g_hPageSystem, (HMENU)ID_RADIO_JOIN_DOMAIN, g_hInst, nullptr);
        g_hLblJoinTarget = CreateWindowW(L"STATIC", L"Ziel (Domain/WG)", WS_CHILD | WS_VISIBLE,
            0, 0, 0, 0, g_hPageSystem, (HMENU)ID_LABEL_JOIN_TARGET, g_hInst, nullptr);
        g_hJoinTarget = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
            WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
            0, 0, 0, 0, g_hPageSystem, (HMENU)ID_EDIT_JOIN_TARGET, g_hInst, nullptr);
        g_hLblJoinHostname = CreateWindowW(L"STATIC", L"Hostname", WS_CHILD | WS_VISIBLE,
            0, 0, 0, 0, g_hPageSystem, (HMENU)ID_LABEL_JOIN_HOSTNAME, g_hInst, nullptr);
        g_hJoinHostname = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
            WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
            0, 0, 0, 0, g_hPageSystem, (HMENU)ID_EDIT_JOIN_HOSTNAME, g_hInst, nullptr);
        g_hBtnJoinNow = CreateWindowW(L"BUTTON", L"Join jetzt", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageSystem, (HMENU)ID_BTN_JOIN_NOW, g_hInst, nullptr);

        g_hMigrationInfo = CreateWindowW(L"STATIC", L"Migration (lokal). Backup aendert den Quellrechner nicht.\r\nEs werden nur ausgewaehlte Ordner/Dateien kopiert (kein komplettes Profil).",
            WS_CHILD | WS_VISIBLE, 0, 0, 0, 0, g_hPageMigration, (HMENU)ID_LABEL_MIGRATION_INFO, g_hInst, nullptr);
        g_hMigrationList = CreateWindowExW(WS_EX_CLIENTEDGE, WC_LISTVIEWW, L"",
            WS_CHILD | WS_VISIBLE | LVS_REPORT | LVS_SINGLESEL,
            0, 0, 0, 0, g_hPageMigration, (HMENU)ID_MIGRATION_LIST, g_hInst, nullptr);
        ListView_SetExtendedListViewStyle(g_hMigrationList, LVS_EX_FULLROWSELECT | LVS_EX_CHECKBOXES);
        InitMigrationListColumns();
        g_hLblMigrationPath = CreateWindowW(L"STATIC", L"Backup-Ordner", WS_CHILD | WS_VISIBLE,
            0, 0, 0, 0, g_hPageMigration, (HMENU)ID_LABEL_MIGRATION_PATH, g_hInst, nullptr);
        g_hMigrationPath = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
            WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
            0, 0, 0, 0, g_hPageMigration, (HMENU)ID_EDIT_MIGRATION_PATH, g_hInst, nullptr);
        g_hBtnMigrationBrowse = CreateWindowW(L"BUTTON", L"Browse", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageMigration, (HMENU)ID_BTN_MIGRATION_BROWSE, g_hInst, nullptr);
        g_hLblMigrationInstaller = CreateWindowW(L"STATIC", L"Installer-Ordner", WS_CHILD | WS_VISIBLE,
            0, 0, 0, 0, g_hPageMigration, (HMENU)ID_LABEL_MIGRATION_INSTALLER, g_hInst, nullptr);
        g_hMigrationInstallerPath = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
            WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
            0, 0, 0, 0, g_hPageMigration, (HMENU)ID_EDIT_MIGRATION_INSTALLER, g_hInst, nullptr);
        g_hBtnMigrationInstallerBrowse = CreateWindowW(L"BUTTON", L"Browse", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageMigration, (HMENU)ID_BTN_MIGRATION_INSTALLER_BROWSE, g_hInst, nullptr);
        g_hBtnMigrationSelectAll = CreateWindowW(L"BUTTON", L"Alle", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageMigration, (HMENU)ID_BTN_MIGRATION_SELECT_ALL, g_hInst, nullptr);
        g_hBtnMigrationClear = CreateWindowW(L"BUTTON", L"Keine", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageMigration, (HMENU)ID_BTN_MIGRATION_CLEAR, g_hInst, nullptr);
        g_hBtnMigrationBackup = CreateWindowW(L"BUTTON", L"Backup", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageMigration, (HMENU)ID_BTN_MIGRATION_BACKUP, g_hInst, nullptr);
        g_hBtnMigrationRestore = CreateWindowW(L"BUTTON", L"Restore", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageMigration, (HMENU)ID_BTN_MIGRATION_RESTORE, g_hInst, nullptr);

        g_hBrowserInfo = CreateWindowW(L"STATIC", L"Browser-Profile sichern/restore. Bitte Browser schliessen.\r\nPasswoerter fuer Chromium-Browser benoetigen DPAPI-Backup und denselben Windows-Benutzer (SID).",
            WS_CHILD | WS_VISIBLE, 0, 0, 0, 0, g_hPageBrowser, (HMENU)ID_LABEL_BROWSER_INFO, g_hInst, nullptr);
        g_hBrowserList = CreateWindowExW(WS_EX_CLIENTEDGE, WC_LISTVIEWW, L"",
            WS_CHILD | WS_VISIBLE | LVS_REPORT | LVS_SINGLESEL,
            0, 0, 0, 0, g_hPageBrowser, (HMENU)ID_BROWSER_LIST, g_hInst, nullptr);
        ListView_SetExtendedListViewStyle(g_hBrowserList, LVS_EX_FULLROWSELECT | LVS_EX_CHECKBOXES);
        InitBrowserListColumns();
        g_hLblBrowserPath = CreateWindowW(L"STATIC", L"Backup-Ordner", WS_CHILD | WS_VISIBLE,
            0, 0, 0, 0, g_hPageBrowser, (HMENU)ID_LABEL_BROWSER_PATH, g_hInst, nullptr);
        g_hBrowserPath = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
            WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
            0, 0, 0, 0, g_hPageBrowser, (HMENU)ID_EDIT_BROWSER_PATH, g_hInst, nullptr);
        g_hBtnBrowserBrowse = CreateWindowW(L"BUTTON", L"Browse", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageBrowser, (HMENU)ID_BTN_BROWSER_BROWSE, g_hInst, nullptr);
        g_hChkBrowserDpapi = CreateWindowW(L"BUTTON", L"DPAPI-Keys sichern/restore (Passwoerter)", WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX,
            0, 0, 0, 0, g_hPageBrowser, (HMENU)ID_CHK_BROWSER_DPAPI, g_hInst, nullptr);
        g_hBtnBrowserSelectAll = CreateWindowW(L"BUTTON", L"Alle", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageBrowser, (HMENU)ID_BTN_BROWSER_SELECT_ALL, g_hInst, nullptr);
        g_hBtnBrowserClear = CreateWindowW(L"BUTTON", L"Keine", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageBrowser, (HMENU)ID_BTN_BROWSER_CLEAR, g_hInst, nullptr);
        g_hBtnBrowserBackup = CreateWindowW(L"BUTTON", L"Backup", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageBrowser, (HMENU)ID_BTN_BROWSER_BACKUP, g_hInst, nullptr);
        g_hBtnBrowserRestore = CreateWindowW(L"BUTTON", L"Restore", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageBrowser, (HMENU)ID_BTN_BROWSER_RESTORE, g_hInst, nullptr);

        g_hConfigInfo = CreateWindowW(L"STATIC", L"Config-Datei enthaelt Apps, Auswahl, Power und Custom-Presets.", WS_CHILD | WS_VISIBLE,
            0, 0, 0, 0, g_hPageConfig, nullptr, g_hInst, nullptr);
        g_hLblConfigPath = CreateWindowW(L"STATIC", L"Config", WS_CHILD | WS_VISIBLE,
            0, 0, 0, 0, g_hPageConfig, (HMENU)ID_LABEL_CONFIG_PATH, g_hInst, nullptr);
        g_hConfigPath = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
            WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
            0, 0, 0, 0, g_hPageConfig, (HMENU)ID_EDIT_CONFIG_PATH, g_hInst, nullptr);
        g_hBtnConfigBrowse = CreateWindowW(L"BUTTON", L"Browse", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageConfig, (HMENU)ID_BTN_CONFIG_BROWSE, g_hInst, nullptr);
        g_hBtnConfigLoad = CreateWindowW(L"BUTTON", L"Laden", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageConfig, (HMENU)ID_BTN_CONFIG_LOAD, g_hInst, nullptr);
        g_hBtnConfigSave = CreateWindowW(L"BUTTON", L"Speichern", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPageConfig, (HMENU)ID_BTN_CONFIG_SAVE, g_hInst, nullptr);

        g_hGroupPower = CreateWindowW(L"BUTTON", L"Energieoptionen", WS_CHILD | WS_VISIBLE | BS_GROUPBOX,
            0, 0, 0, 0, g_hPagePower, (HMENU)ID_GROUP_POWER, g_hInst, nullptr);
        g_hChkFastStartup = CreateWindowW(L"BUTTON", L"Schnellstart deaktivieren", WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX,
            0, 0, 0, 0, g_hPagePower, (HMENU)ID_CHK_FAST_STARTUP, g_hInst, nullptr);
        g_hChkHibernateAC = CreateWindowW(L"BUTTON", L"Ruhezustand (Netzbetrieb) Min", WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX,
            0, 0, 0, 0, g_hPagePower, (HMENU)ID_CHK_HIBERNATE_AC, g_hInst, nullptr);
        g_hEditHibernateAC = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
            WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
            0, 0, 0, 0, g_hPagePower, (HMENU)ID_EDIT_HIBERNATE_AC, g_hInst, nullptr);
        g_hChkMonitorAC = CreateWindowW(L"BUTTON", L"Bildschirm aus (Netzbetrieb) Min", WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX,
            0, 0, 0, 0, g_hPagePower, (HMENU)ID_CHK_MONITOR_AC, g_hInst, nullptr);
        g_hEditMonitorAC = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
            WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
            0, 0, 0, 0, g_hPagePower, (HMENU)ID_EDIT_MONITOR_AC, g_hInst, nullptr);
        g_hChkSleepAC = CreateWindowW(L"BUTTON", L"Standby (Netzbetrieb) Min", WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX,
            0, 0, 0, 0, g_hPagePower, (HMENU)ID_CHK_SLEEP_AC, g_hInst, nullptr);
        g_hEditSleepAC = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
            WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
            0, 0, 0, 0, g_hPagePower, (HMENU)ID_EDIT_SLEEP_AC, g_hInst, nullptr);
        g_hChkHibernateDC = CreateWindowW(L"BUTTON", L"Ruhezustand (Akku) Min", WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX,
            0, 0, 0, 0, g_hPagePower, (HMENU)ID_CHK_HIBERNATE_DC, g_hInst, nullptr);
        g_hEditHibernateDC = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
            WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
            0, 0, 0, 0, g_hPagePower, (HMENU)ID_EDIT_HIBERNATE_DC, g_hInst, nullptr);
        g_hChkMonitorDC = CreateWindowW(L"BUTTON", L"Bildschirm aus (Akku) Min", WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX,
            0, 0, 0, 0, g_hPagePower, (HMENU)ID_CHK_MONITOR_DC, g_hInst, nullptr);
        g_hEditMonitorDC = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
            WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
            0, 0, 0, 0, g_hPagePower, (HMENU)ID_EDIT_MONITOR_DC, g_hInst, nullptr);
        g_hBtnApplyPower = CreateWindowW(L"BUTTON", L"Energie anwenden", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            0, 0, 0, 0, g_hPagePower, (HMENU)ID_BTN_APPLY_POWER, g_hInst, nullptr);

        HFONT hFont = (HFONT)GetStockObject(DEFAULT_GUI_FONT);
        SendMessageW(g_hTab, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hList, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnInstall, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnPreset, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnSelectAll, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnClear, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnRunAll, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hCustomList, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hLblCustomName, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hLblCustomPath, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hLblCustomArgs, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hCustomName, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hCustomPath, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnBrowse, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hCustomArgs, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnRunCustom, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnInstallAllCustom, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnCustomAdd, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnCustomRemove, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hGroupUsers, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hUserList, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hLblUserName, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hUserName, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hLblUserGroups, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hUserGroups, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnUserAdd, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnUserRemove, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnUserCreate, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hGroupJoin, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hChkJoinEnable, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hRadioWorkgroup, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hRadioDomain, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hLblJoinTarget, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hJoinTarget, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hLblJoinHostname, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hJoinHostname, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnJoinNow, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hMigrationInfo, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hMigrationList, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hLblMigrationPath, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hMigrationPath, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnMigrationBrowse, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hLblMigrationInstaller, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hMigrationInstallerPath, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnMigrationInstallerBrowse, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnMigrationSelectAll, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnMigrationClear, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnMigrationBackup, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnMigrationRestore, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBrowserInfo, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBrowserList, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hLblBrowserPath, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBrowserPath, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnBrowserBrowse, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hChkBrowserDpapi, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnBrowserSelectAll, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnBrowserClear, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnBrowserBackup, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnBrowserRestore, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hGroupPower, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hChkFastStartup, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hChkHibernateAC, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hEditHibernateAC, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hChkMonitorAC, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hEditMonitorAC, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hChkSleepAC, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hEditSleepAC, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hChkHibernateDC, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hEditHibernateDC, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hChkMonitorDC, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hEditMonitorDC, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnApplyPower, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hLog, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hConfigInfo, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hLblConfigPath, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hConfigPath, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnConfigBrowse, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnConfigLoad, WM_SETFONT, (WPARAM)hFont, TRUE);
        SendMessageW(g_hBtnConfigSave, WM_SETFONT, (WPARAM)hFont, TRUE);

        SetChecked(g_hChkFastStartup, g_power.disableFastStartup);
        SetChecked(g_hChkHibernateAC, g_power.hibernateAC.enabled);
        SetEditInt(g_hEditHibernateAC, g_power.hibernateAC.minutes);
        SetChecked(g_hChkMonitorAC, g_power.monitorAC.enabled);
        SetEditInt(g_hEditMonitorAC, g_power.monitorAC.minutes);
        SetChecked(g_hChkSleepAC, g_power.sleepAC.enabled);
        SetEditInt(g_hEditSleepAC, g_power.sleepAC.minutes);
        SetChecked(g_hChkHibernateDC, g_power.hibernateDC.enabled);
        SetEditInt(g_hEditHibernateDC, g_power.hibernateDC.minutes);
        SetChecked(g_hChkMonitorDC, g_power.monitorDC.enabled);
        SetEditInt(g_hEditMonitorDC, g_power.monitorDC.minutes);

        SetWindowTextW(g_hConfigPath, g_iniPath.c_str());
        SetWindowTextW(g_hMigrationPath, g_migrationBackupPath.c_str());
        SetWindowTextW(g_hMigrationInstallerPath, g_migrationInstallerPath.c_str());
        SetWindowTextW(g_hBrowserPath, g_browserBackupPath.c_str());
        SetChecked(g_hChkBrowserDpapi, true);
        PopulateCustomList();
        PopulateUserList();
        PopulateMigrationList();
        PopulateBrowserList();
        SetChecked(g_hChkJoinEnable, g_join.enabled);
        SendMessageW(g_hRadioWorkgroup, BM_SETCHECK, g_join.type == JoinType::Workgroup ? BST_CHECKED : BST_UNCHECKED, 0);
        SendMessageW(g_hRadioDomain, BM_SETCHECK, g_join.type == JoinType::Domain ? BST_CHECKED : BST_UNCHECKED, 0);
        if (g_join.hostname.empty()) {
            g_join.hostname = GetCurrentHostname();
        }
        SetWindowTextW(g_hJoinTarget, g_join.target.c_str());
        SetWindowTextW(g_hJoinHostname, g_join.hostname.c_str());
        PopulateList();
        LayoutControls();
        return 0;
    }
    case WM_SIZE:
        LayoutControls();
        return 0;
    case WM_COMMAND:
        switch (LOWORD(wParam)) {
        case ID_BTN_INSTALL:
            InstallSelected();
            return 0;
        case ID_BTN_PRESET:
            ApplyPreset();
            return 0;
        case ID_BTN_SELECT_ALL:
            SelectAll(true);
            return 0;
        case ID_BTN_CLEAR:
            SelectAll(false);
            return 0;
        case ID_BTN_RUN_ALL:
            RunAll();
            return 0;
        case ID_BTN_CUSTOM_ADD:
            AddCustomPresetFromFields();
            return 0;
        case ID_BTN_CUSTOM_REMOVE:
            RemoveSelectedCustomPresets();
            return 0;
        case ID_BTN_USER_ADD:
            AddUserFromFields();
            return 0;
        case ID_BTN_USER_REMOVE:
            RemoveSelectedUsers();
            return 0;
        case ID_BTN_USER_CREATE:
            CreateLocalUsers();
            return 0;
        case ID_BTN_BROWSE:
            DoBrowse();
            return 0;
        case ID_BTN_RUN_CUSTOM:
            RunCustomInstaller();
            return 0;
        case ID_BTN_INSTALL_ALL_CUSTOM:
            InstallAllCustomPresets();
            return 0;
        case ID_BTN_JOIN_NOW:
            JoinFromUI();
            return 0;
        case ID_BTN_APPLY_POWER:
            ApplyPowerTweaks();
            return 0;
        case ID_BTN_CONFIG_BROWSE:
            DoConfigBrowse();
            return 0;
        case ID_BTN_CONFIG_LOAD:
            LoadConfigFromPath(GetEditText(g_hConfigPath));
            return 0;
        case ID_BTN_CONFIG_SAVE:
            SaveConfigToPath(GetEditText(g_hConfigPath));
            return 0;
        case ID_BTN_MIGRATION_BROWSE:
            DoMigrationBrowse();
            return 0;
        case ID_BTN_MIGRATION_INSTALLER_BROWSE:
            DoMigrationInstallerBrowse();
            return 0;
        case ID_BTN_MIGRATION_BACKUP:
            BackupMigration();
            return 0;
        case ID_BTN_MIGRATION_RESTORE:
            RestoreMigration();
            return 0;
        case ID_BTN_MIGRATION_SELECT_ALL:
            SelectAllMigration(true);
            return 0;
        case ID_BTN_MIGRATION_CLEAR:
            SelectAllMigration(false);
            return 0;
        case ID_BTN_BROWSER_BROWSE:
            DoBrowserBrowse();
            return 0;
        case ID_BTN_BROWSER_BACKUP:
            BackupBrowsers();
            return 0;
        case ID_BTN_BROWSER_RESTORE:
            RestoreBrowsers();
            return 0;
        case ID_BTN_BROWSER_SELECT_ALL:
            SelectAllBrowsers(true);
            return 0;
        case ID_BTN_BROWSER_CLEAR:
            SelectAllBrowsers(false);
            return 0;
        case ID_EDIT_MIGRATION_PATH:
            if (HIWORD(wParam) == EN_CHANGE) {
                UpdateMigrationBackupStatus();
                return 0;
            }
            break;
        case ID_EDIT_BROWSER_PATH:
            if (HIWORD(wParam) == EN_CHANGE) {
                UpdateBrowserBackupStatus();
                return 0;
            }
            break;
        default:
            break;
        }
        break;
    case WM_NOTIFY: {
        LPNMHDR hdr = reinterpret_cast<LPNMHDR>(lParam);
        if (hdr->hwndFrom == g_hTab && hdr->code == TCN_SELCHANGE) {
            int sel = TabCtrl_GetCurSel(g_hTab);
            HWND pages[] = { g_hPageInstall, g_hPageCustom, g_hPageSystem, g_hPageMigration, g_hPageBrowser, g_hPagePower, g_hPageConfig };
            for (int i = 0; i < 7; ++i) {
                ShowWindow(pages[i], (i == sel) ? SW_SHOW : SW_HIDE);
            }
            if (sel >= 0 && sel < 7) {
                SetWindowPos(pages[sel], HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
            }
            LayoutControls();
            return 0;
        }
        if (hdr->hwndFrom == g_hCustomList && hdr->code == LVN_ITEMCHANGED) {
            auto nmlv = reinterpret_cast<LPNMLISTVIEW>(lParam);
            if ((nmlv->uNewState & LVIS_SELECTED) && nmlv->iItem >= 0 && nmlv->iItem < static_cast<int>(g_customPresets.size())) {
                const auto& p = g_customPresets[nmlv->iItem];
                SetWindowTextW(g_hCustomName, p.name.c_str());
                SetWindowTextW(g_hCustomPath, p.path.c_str());
                SetWindowTextW(g_hCustomArgs, p.args.c_str());
            }
        }
        if (hdr->hwndFrom == g_hUserList && hdr->code == LVN_ITEMCHANGED) {
            auto nmlv = reinterpret_cast<LPNMLISTVIEW>(lParam);
            if ((nmlv->uNewState & LVIS_SELECTED) && nmlv->iItem >= 0 && nmlv->iItem < static_cast<int>(g_users.size())) {
                const auto& u = g_users[nmlv->iItem];
                SetWindowTextW(g_hUserName, u.name.c_str());
                SetWindowTextW(g_hUserGroups, u.groups.c_str());
            }
        }
        break;
    }
    case WM_CLOSE:
        DestroyWindow(hWnd);
        return 0;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    default:
        break;
    }
    return DefWindowProcW(hWnd, msg, wParam, lParam);
}

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE, PWSTR, int nCmdShow) {
    g_hInst = hInstance;

    if (!IsElevated()) {
        MessageBoxW(nullptr, L"Please run this app as Administrator.", kAppTitle, MB_ICONERROR);
        return 1;
    }

    INITCOMMONCONTROLSEX icc{};
    icc.dwSize = sizeof(icc);
    icc.dwICC = ICC_LISTVIEW_CLASSES | ICC_TAB_CLASSES;
    InitCommonControlsEx(&icc);

    std::wstring exeDir = GetExeDir();
    g_iniPath = exeDir + L"\\" + kIniFile;
    g_browserBackupPath = exeDir + L"\\BrowserBackup";
    g_migrationBackupPath = exeDir + L"\\MigrationBackup";
    g_migrationInstallerPath = exeDir + L"\\Installers";

    g_configLoaded = LoadConfigFile(g_iniPath);
    if (!g_configLoaded) {
        LoadDefaultConfig();
    }
    if (g_join.hostname.empty()) {
        g_join.hostname = GetCurrentHostname();
    }
    LoadCustomPresets();
    LoadUsers();
    LoadBrowserItems();
    LoadMigrationItems();

    WNDCLASSW wc{};
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = L"BloatRemoverGuiWnd";
    wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    RegisterClassW(&wc);

    WNDCLASSW pc{};
    pc.lpfnWndProc = PageWndProc;
    pc.hInstance = hInstance;
    pc.lpszClassName = kPageClass;
    pc.hCursor = LoadCursor(nullptr, IDC_ARROW);
    pc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    RegisterClassW(&pc);

    WNDCLASSW jc{};
    jc.lpfnWndProc = JoinPromptProc;
    jc.hInstance = hInstance;
    jc.lpszClassName = kJoinPromptClass;
    jc.hCursor = LoadCursor(nullptr, IDC_ARROW);
    jc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    RegisterClassW(&jc);

    g_hWnd = CreateWindowExW(0, wc.lpszClassName, kAppTitle,
        WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 820, 620,
        nullptr, nullptr, hInstance, nullptr);
    if (!g_hWnd) return 1;

    ShowWindow(g_hWnd, nCmdShow);
    UpdateWindow(g_hWnd);

    if (g_configLoaded && g_join.enabled) {
        if (g_join.target.empty()) {
            MessageBoxW(g_hWnd, L"Join aktiviert, aber Ziel (Domain/Workgroup) fehlt in config.ini.", kAppTitle, MB_ICONWARNING);
        } else {
            std::wstring hostname = g_join.hostname.empty() ? GetCurrentHostname() : g_join.hostname;
            if (PromptHostnameOnly(g_hWnd, hostname)) {
                g_join.hostname = hostname;
                SetWindowTextW(g_hJoinHostname, hostname.c_str());
                JoinDomainOrWorkgroup(g_join.type, g_join.target, hostname);
            }
        }
    }

    AppendLog(L"Ready.");
    if (!g_presetName.empty()) {
        AppendLog(L"Preset: " + g_presetName);
    }

    MSG msg{};
    while (GetMessageW(&msg, nullptr, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
    return 0;
}
