// Hey, Emacs, this a -*-C++-*- file !

// Copyright distributed.net 1997-1999 - All Rights Reserved
// For use in distributed.net projects only.
// Any other distribution or use of this source violates copyright.
//
// $Log: network.h,v $
// Revision 1.59  1999/03/18 04:01:35  cyp
// new network class method: Reset()
//
// Revision 1.58  1999/02/03 03:41:56  cyp
// InitializeConnectivity()/DeinitializeConnectivity() are now in netinit.cpp
//
// Revision 1.57  1999/02/01 18:02:44  cyp
// undid last SillyB change. (so, whats new?)
//
// Revision 1.56  1999/02/01 08:20:00  silby
// Network class once again allows autofindkeyserver to be disabled.
//
// Revision 1.55  1999/01/31 20:19:09  cyp
// Discarded all 'bool' type wierdness. See cputypes.h for explanation.
//
// Revision 1.54  1999/01/29 18:57:10  jlawson
// fixed formatting.  changed some int vars to bool.
//
// Revision 1.53  1999/01/29 04:12:37  cyp
// NetOpen() no longer needs the autofind setting to be passed from the client.
//
// Revision 1.52  1999/01/23 21:36:10  patrick
// OS2-EMX supports close (doesn't even know about soclose ;-)
//
// Revision 1.51  1999/01/21 22:01:04  cyp
// fixed LowLevelSend() which didn't know /anything/ about non-blocking sox.
//
// Revision 1.50  1999/01/08 02:57:37  michmarc
// Wrapper around #define STRICT to avoid a _HUGE_ pile of warnings
// under VC6/AlphaNT
//
// Revision 1.49  1999/01/05 22:44:34  cyp
// Resolve() copies the hostname being resolved (first if from a list) to a
// buffer in the network object. This is later used by SOCKS5 if lookup fails.
//
// Revision 1.48  1999/01/04 04:47:55  cyp
// Minor fixes for platforms without network support.
//
// Revision 1.47  1999/01/02 07:18:23  dicamillo
// Add ctype.h for BeOS.
//
// Revision 1.46  1999/01/01 02:45:16  cramer
// Part 1 of 1999 Copyright updates...
//
// Revision 1.45  1998/12/31 17:55:50  cyp
// changes to Network::Open(): (a) retry loop is inside ::Open() (was from
// the external NetOpen()) (b) cleaned up the various hostname/addr/port
// variables to make sense and be uniform throughout. (c) nofallback handling
// is performed by ::Open() and not by the external NetOpen().
//
// Revision 1.44  1998/12/24 05:19:55  dicamillo
// Add socket_ioctl to Mac OS definitions.
//

//#define SELECT_FIRST      // define to perform select() before reading
//#define __VMS_UCX__       // define for UCX instead of Multinet on VMS

///////////////////////////////////////////////////////////////////////////

#ifndef NETWORK_H
#define NETWORK_H

#define NETTIMEOUT (60)

#include "cputypes.h"
#include "autobuff.h"


#if ((CLIENT_OS == OS_AMIGAOS)|| (CLIENT_OS == OS_RISCOS))
extern "C" {
#endif

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>    // for offsetof
#include <time.h>
#include <errno.h>     // for errno and EINTR

#if ((CLIENT_OS == OS_AMIGAOS) || (CLIENT_OS == OS_RISCOS))
}
#endif

#if (CLIENT_OS == OS_WIN32) || (CLIENT_OS == OS_WIN16) || (CLIENT_OS == OS_WIN32S)
  #define WIN32_LEAN_AND_MEAN
  #ifndef STRICT
    #define STRICT
  #endif
  #include <windows.h>
  #if (CLIENT_OS == OS_WIN32)
  #include <winsock.h>
  #else
  #include "w32sock.h" //winsock wrappers
  #endif
  #include <io.h>
  #define write(sock, buff, len) send(sock, (char*)buff, (int)len, 0)
  #define read(sock, buff, len) recv(sock, (char*)buff, (int)len, 0)
  #define close(sock) closesocket(sock)
#elif (CLIENT_OS == OS_RISCOS)
  extern "C" {
  #include <socklib.h>
  #include <inetlib.h>
  #include <unixlib.h>
  #include <sys/ioctl.h>
  #include <unistd.h>
  #include <netdb.h>
  #define SOCKET int
  }
#elif (CLIENT_OS == OS_DOS) 
  //generally NO!NETWORK, but to be safe we...
  #include "platform/dos/clidos.h" 
#elif (CLIENT_OS == OS_VMS)
  #include <signal.h>
  #ifdef __VMS_UCX__
    #include <sys/types.h>
    #include <sys/socket.h>
    #include <netinet/in.h>
    #include <arpa/inet.h>
    #include <sys/time.h>
    #include <unistd.h>
    #include <fcntl.h>
    #include <netdb.h>
    #include <unixio.h>
  #elif defined(MULTINET)
    #include "multinet_root:[multinet.include.sys]types.h"
    #include "multinet_root:[multinet.include.sys]ioctl.h"
    #include "multinet_root:[multinet.include.sys]param.h"
    #include "multinet_root:[multinet.include.sys]time.h"
    #include "multinet_root:[multinet.include.sys]socket.h"
    #include "multinet_root:[multinet.include]netdb.h"
    #include "multinet_root:[multinet.include.netinet]in.h"
    #include "multinet_root:[multinet.include.netinet]in_systm.h"
    #ifndef multinet_inet_addr
      extern "C" unsigned long int inet_addr(const char *cp);
    #endif
    #ifndef multinet_inet_ntoa
      extern "C" char *inet_ntoa(struct in_addr in);
    #endif
    #define write(sock, buff, len) socket_write(sock, buff, len)
    #define read(sock, buff, len) socket_read(sock, buff, len)
    #define close(sock) socket_close(sock)
  #endif
  typedef int SOCKET;
#elif (CLIENT_OS == OS_MACOS)
  #include "socket_glue.h"
  #define write(sock, buff, len) socket_write(sock, buff, len)
  #define read(sock, buff, len) socket_read(sock, buff, len)
  #define close(sock) socket_close(sock)
  #define ioctl(sock, request, arg) socket_ioctl(sock, request, arg)
  extern Boolean myNetInit(void);
#elif (CLIENT_OS == OS_OS2)
  #include <process.h>
  #include <io.h>

  #if defined(__WATCOMC__)
    #include <i86.h>
  #endif
  // All the OS/2 specific headers are here
  // This is neccessary since the order of the OS/2 defines are important
  #include "platforms/os2cli/os2defs.h"
  typedef int SOCKET;
  #if !defined(__EMX__)
  #define close(s) soclose(s)
  #endif
  #define read(sock, buff, len) recv(sock, (char*)buff, len, 0)
  #define write(sock, buff, len) send(sock, (char*)buff, len, 0)
#elif (CLIENT_OS == OS_AMIGAOS)
  extern "C" {
  #include "platforms/amiga/amiga.h"
  #include <assert.h>
  #include <clib/socket_protos.h>
  #include <pragmas/socket_pragmas.h>
  #include <sys/ioctl.h>
  #include <sys/time.h>
  #include <netdb.h>
  extern struct Library *SocketBase;
  #define write(sock, buff, len) send(sock, (unsigned char*)buff, len, 0)
  #define read(sock, buff, len) recv(sock, (unsigned char*)buff, len, 0)
  #define close(sock) CloseSocket(sock)
  #define inet_ntoa(addr) Inet_NtoA(addr.s_addr)
  #ifndef __PPC__
     #define inet_addr(host) inet_addr((unsigned char *)host)
     #define gethostbyname(host) gethostbyname((unsigned char *)host)
  #endif
  typedef int SOCKET;
  }
#elif (CLIENT_OS == OS_BEOS)
  #include <sys/types.h>
  #include <sys/socket.h>
  #include <netinet/in.h>
  #include <sys/time.h>
  #include <unistd.h>
  #include <fcntl.h>
  #include <netdb.h>
  #include <ctype.h>
  typedef int SOCKET;
  #define write(sock, buff, len) send(sock, (unsigned char*)buff, len, 0)
  #define read(sock, buff, len) recv(sock, (unsigned char*)buff, len, 0)
  #define close(sock) closesocket(sock)
#else

#if (CLIENT_OS == OS_QNX)
  #include <sys/select.h>
#endif
  #include <sys/types.h>
  #include <sys/socket.h>
  #include <netinet/in.h>
  #include <arpa/inet.h>
  #include <sys/time.h>
  #include <unistd.h>
  #include <fcntl.h>
  #include <netdb.h>
  typedef int SOCKET;
  #if (CLIENT_OS == OS_LINUX) && (CLIENT_CPU == CPU_ALPHA)
    #include <asm/byteorder.h>
  #elif (CLIENT_OS == OS_DYNIX) && defined(NTOHL)
    #define ntohl(x)  NTOHL(x)
    #define htonl(x)  HTONL(x)
    #define ntohs(x)  NTOHS(x)
    #define htons(x)  HTONS(x)
  #endif
  #if (CLIENT_OS == OS_AIX) || (CLIENT_OS == OS_DYNIX)
    #include <errno.h>
  #endif
  #if ((CLIENT_OS == OS_SUNOS) && (CLIENT_CPU==CPU_68K))
    #if defined(_SUNOS3_)
      #define _SOCKET_H_ALREADY_
      extern "C" int fcntl(int, int, int);
    #endif
    extern "C" {
    int socket(int, int, int);
    int setsockopt(int, int, int, char *, int);
    int connect(int, struct sockaddr *, int);
    }
  #endif
  #if (CLIENT_OS == OS_ULTRIX)
    extern "C" {
      int socket(int, int, int);
      int setsockopt(int, int, int, char *, int);
      int connect(int, struct sockaddr *, int);
    }
  #endif
  #if (CLIENT_OS == OS_NETWARE)
    #include "platforms/netware/netware.h" //symbol redefinitions
    extern "C" {
    #pragma pack(1)
    #include <tiuser.h> //using TLI
    #pragma pack()
    }
  #endif  
#endif

////////////////////////////////////////////////////////////////////////////

#define MODE_UUE        1
#define MODE_HTTP       2
#define MODE_SOCKS4     4
#define MODE_PROXIED    (MODE_HTTP | MODE_SOCKS4 | MODE_SOCKS5)
#define MODE_SOCKS5     8
#define DEFAULT_RRDNS   ""
#define DEFAULT_PORT    2064
#define CONDSOCK_BLOCKING_ON     0x0011
#define CONDSOCK_BLOCKING_OFF    0x0010
#define CONDSOCK_KEEPALIVE_ON    0x0021
#define CONDSOCK_KEEPALIVE_OFF   0x0020
#ifndef INVALID_SOCKET
#define INVALID_SOCKET  ((SOCKET)(-1))
#endif

////////////////////////////////////////////////////////////////////////////

int InitializeConnectivity(void);   //per instance initialization
int DeinitializeConnectivity(void);

class Network
{
protected:
  char server_name[64];   // used only by ::Open
  int server_port;       // used only by ::Open
  int nofallback;        // used only by ::Open

  int  startmode;
  int autofindkeyserver; // implies 'only if hostname is a dnet keyserver'
  int  verbose_level;     // 0 == no messages, 1 == user, 2 = diagnostic/debug
  int  iotimeout;         // use blocking calls if iotimeout is <0

  int  mode;              // startmode as modified at runtime
  SOCKET sock;            // socket file handle
  int isnonblocking;     // whether the socket could be set non-blocking
  int reconnected;       // set to 1 once a connect succeeds 

  char fwall_hostname[64]; //intermediate
  int  fwall_hostport;
  u32  fwall_hostaddr;
  char fwall_userpass[128]; //username+password
  char resolve_hostname[64]; //last hostname Resolve() did a lookup on.
                          //used by socks5 if the svc_hostname doesn't resolve

  char *svc_hostname;  //name of the final dest (server_name or rrdns_name)
  int  svc_hostport;   //the port of the final destination
  u32  svc_hostaddr;   //resolved if direct connection or socks.

  char *conn_hostname; //hostname we connect()ing to (fwall or server)
  int  conn_hostport;  //port we are connect()ing to
  u32  conn_hostaddr;  //the address we are connect()ing to

  // communications and decoding buffers
  AutoBuffer netbuffer, uubuffer;
  int gotuubegin, gothttpend, puthttpdone, gethttpdone;
  u32 httplength;

  int LowLevelCreateSocket(void);
    // Returns < 0 on error, else assigns fd to this->sock and returns 0.
    
  int LowLevelCloseSocket(void);
    // destroys this->sock if (this->sock != INVALID_SOCKET) and returns 0.

  int LowLevelConnectSocket( u32 that_address, u16 that_port ); 
    // connect to address:port.  Return < 0 if error

  int LowLevelConditionSocket( unsigned long cond_type );
    // Returns < 0 if error - see CONDSOCK... defines above

  int LowLevelGet(char *data, int length);
    // returns 0 if sock closed, -1 if timeout, else length of rcvd data

  int LowLevelPut(const char *data, int length);
    // returns 0 if sock closed, -1 if timeout, else length of sent data

  int Resolve( const char *host, u32 *hostaddress, int hostport ); //LowLevel
    // perform a DNS lookup, handling random selection of DNS lists
    // returns < 0 on error, 0 on success

  int InitializeConnection(void); //high level method. Used internally by Open
    //currently only negotiates/authenticates the SOCKSx session. 
    // returns < 0 on error, 0 on success

  int  Close( void );
    // close the connection

  int MakeBlocking(void) // make the socket operate in blocking mode.
      { return LowLevelConditionSocket( CONDSOCK_BLOCKING_ON ); }

  int MakeNonBlocking(void) //the other shortcut
      { return LowLevelConditionSocket( CONDSOCK_BLOCKING_OFF ); };

  int  Open( void );
    // [re]open the connection using the current settings.
    // returns -1 on error, 0 on success

  ~Network( void );
    // guess. 
 
  Network( const char *servname, int servport, 
           int _nofallback = 1, int _iotimeout = -1, int _enctype = 0, 
           const char *_fwallhost = NULL, int _fwallport = 0, 
           const char *_fwalluid = NULL );
    // protected!: used by friend NetOpen() below.

public:

  friend Network *NetOpen( const char *servname, int servport, 
           int _nofallback = 1, int _iotimeout = -1, int _enctype = 0, 
           const char *_fwallhost = NULL, int _fwallport = 0, 
           const char *_fwalluid = NULL );

  friend int NetClose( Network *net );

  int Get( char * data, int length );
    // recv data over the open connection, handle uue/http translation,
    // Returns length of read buffer.

  int Put( const char * data, int length );
    // send data over the open connection, handle uue/http translation,
    // Returns length of sent buffer

  int GetHostName( char *buffer, unsigned int len );
    // used by mail.
    // like gethostname(). returns !0 on error

  int SetPeerAddress( u32 addr ) 
    { if (svc_hostaddr == 0) svc_hostaddr = addr; return 0; }
    // used by buffupd when proxies return an address in the scram packet
    
  int Reset( int fallbacknow );
    // reset the connection (hard!), with optional immediate fallback
    // the old connection is invalid on return (even if reset fails). 
    
};

///////////////////////////////////////////////////////////////////////////

#endif //NETWORK_H

