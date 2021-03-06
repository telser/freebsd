//===-- PlatformRemoteGDBServer.h ----------------------------------------*- C++ -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef liblldb_PlatformRemoteGDBServer_h_
#define liblldb_PlatformRemoteGDBServer_h_

// C Includes
// C++ Includes
#include <string>

// Other libraries and framework includes
// Project includes
#include "lldb/Target/Platform.h"
#include "../../Process/gdb-remote/GDBRemoteCommunicationClient.h"
#include "Plugins/Process/Utility/GDBRemoteSignals.h"

namespace lldb_private {
namespace platform_gdb_server {

class PlatformRemoteGDBServer : public Platform
{
public:

    static void
    Initialize ();

    static void
    Terminate ();
    
    static lldb::PlatformSP
    CreateInstance (bool force, const ArchSpec *arch);

    static ConstString
    GetPluginNameStatic();

    static const char *
    GetDescriptionStatic();


    PlatformRemoteGDBServer ();

    virtual
    ~PlatformRemoteGDBServer();

    //------------------------------------------------------------
    // lldb_private::PluginInterface functions
    //------------------------------------------------------------
    ConstString
    GetPluginName() override
    {
        return GetPluginNameStatic();
    }
    
    uint32_t
    GetPluginVersion() override
    {
        return 1;
    }
    

    //------------------------------------------------------------
    // lldb_private::Platform functions
    //------------------------------------------------------------
    Error
    ResolveExecutable (const ModuleSpec &module_spec,
                       lldb::ModuleSP &module_sp,
                       const FileSpecList *module_search_paths_ptr) override;

    bool
    GetModuleSpec (const FileSpec& module_file_spec,
                   const ArchSpec& arch,
                   ModuleSpec &module_spec) override;

    const char *
    GetDescription () override;

    Error
    GetFileWithUUID (const FileSpec &platform_file, 
                     const UUID *uuid_ptr,
                     FileSpec &local_file) override;

    bool
    GetProcessInfo (lldb::pid_t pid, ProcessInstanceInfo &proc_info) override;
    
    uint32_t
    FindProcesses (const ProcessInstanceInfoMatch &match_info,
                   ProcessInstanceInfoList &process_infos) override;

    Error
    LaunchProcess (ProcessLaunchInfo &launch_info) override;

    Error
    KillProcess (const lldb::pid_t pid) override;

    lldb::ProcessSP
    DebugProcess (ProcessLaunchInfo &launch_info,
                  Debugger &debugger,
                  Target *target,       // Can be NULL, if NULL create a new target, else use existing one
                  Error &error) override;

    lldb::ProcessSP
    Attach (ProcessAttachInfo &attach_info,
            Debugger &debugger,
            Target *target,       // Can be NULL, if NULL create a new target, else use existing one
            Error &error) override;

    bool
    GetSupportedArchitectureAtIndex (uint32_t idx, ArchSpec &arch) override;

    size_t
    GetSoftwareBreakpointTrapOpcode (Target &target, BreakpointSite *bp_site) override;

    bool
    GetRemoteOSVersion () override;

    bool
    GetRemoteOSBuildString (std::string &s) override;
    
    bool
    GetRemoteOSKernelDescription (std::string &s) override;

    // Remote Platform subclasses need to override this function
    ArchSpec
    GetRemoteSystemArchitecture () override;

    FileSpec
    GetRemoteWorkingDirectory() override;
    
    bool
    SetRemoteWorkingDirectory(const FileSpec &working_dir) override;

    // Remote subclasses should override this and return a valid instance
    // name if connected.
    const char *
    GetHostname () override;

    const char *
    GetUserName (uint32_t uid) override;
    
    const char *
    GetGroupName (uint32_t gid) override;

    bool
    IsConnected () const override;

    Error
    ConnectRemote (Args& args) override;

    Error
    DisconnectRemote () override;
    
    Error
    MakeDirectory(const FileSpec &file_spec, uint32_t file_permissions) override;

    Error
    GetFilePermissions(const FileSpec &file_spec, uint32_t &file_permissions) override;

    Error
    SetFilePermissions(const FileSpec &file_spec, uint32_t file_permissions) override;


    lldb::user_id_t
    OpenFile (const FileSpec& file_spec, uint32_t flags, uint32_t mode, Error &error) override;
    
    bool
    CloseFile (lldb::user_id_t fd, Error &error) override;
    
    uint64_t
    ReadFile (lldb::user_id_t fd,
              uint64_t offset,
              void *data_ptr,
              uint64_t len,
              Error &error) override;
    
    uint64_t
    WriteFile (lldb::user_id_t fd,
               uint64_t offset,
               const void* data,
               uint64_t len,
               Error &error) override;

    lldb::user_id_t
    GetFileSize (const FileSpec& file_spec) override;

    Error
    PutFile (const FileSpec& source,
             const FileSpec& destination,
             uint32_t uid = UINT32_MAX,
             uint32_t gid = UINT32_MAX) override;
    
    Error
    CreateSymlink(const FileSpec &src, const FileSpec &dst) override;

    bool
    GetFileExists (const FileSpec& file_spec) override;

    Error
    Unlink(const FileSpec &path) override;

    Error
    RunShellCommand(const char *command,            // Shouldn't be NULL
                    const FileSpec &working_dir,    // Pass empty FileSpec to use the current working directory
                    int *status_ptr,                // Pass NULL if you don't want the process exit status
                    int *signo_ptr,                 // Pass NULL if you don't want the signal that caused the process to exit
                    std::string *command_output,    // Pass NULL if you don't want the command output
                    uint32_t timeout_sec) override; // Timeout in seconds to wait for shell program to finish

    void
    CalculateTrapHandlerSymbolNames () override;

    const lldb::UnixSignalsSP &
    GetRemoteUnixSignals() override;

protected:
    process_gdb_remote::GDBRemoteCommunicationClient m_gdb_client;
    std::string m_platform_description; // After we connect we can get a more complete description of what we are connected to
    std::string m_platform_scheme;
    std::string m_platform_hostname;

    lldb::UnixSignalsSP m_remote_signals_sp;

    // Launch the lldb-gdbserver on the remote host and return the port it is listening on or 0 on
    // failure. Subclasses should override this method if they want to do extra actions before or
    // after launching the lldb-gdbserver.
    virtual uint16_t
    LaunchGDBserverAndGetPort (lldb::pid_t &pid);

    virtual bool
    KillSpawnedProcess (lldb::pid_t pid);

private:
    DISALLOW_COPY_AND_ASSIGN (PlatformRemoteGDBServer);

};

} // namespace platform_gdb_server
} // namespace lldb_private

#endif  // liblldb_PlatformRemoteGDBServer_h_
