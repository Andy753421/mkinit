#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <err.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>

#define INIT_MAGIC            0x03091969
#define INIT_CMD_START        0
#define INIT_CMD_RUNLVL       1
#define INIT_CMD_POWERFAIL    2
#define INIT_CMD_POWERFAILNOW 3
#define INIT_CMD_POWEROK      4
#define INIT_CMD_BSD          5
#define INIT_CMD_SETENV       6
#define INIT_CMD_UNSETENV     7
#define INIT_CMD_CHANGECONS   12345
#define INITRQ_HLEN           64

/**
 * tellinit
 *   0   shutdown
 *   1   single
 *   2   nonetwork
 *   3   default
 *   4   default
 *   5   gui
 *   6   reboot
 *   abc ignored (inittab)
 *   sS  single user
 *   qQ  reload
 *   uU  reload
 * 
 * shutdown
 *   -r, reboot        runlevel 6 5, setenv INIT_HALT
 *   -h, default halt  runlevel 0 5, setenv INIT_HALT
 *   -P, poweroff      runlevel S 5, setenv INIT_HALT=POWERDOWN
 *   -H, just halt     runlevel S 5, setenv INIT_HALT=HALT
 *   -f, skip fsck     runlevel S 5, setenv INIT_HALT
 *   -F, force fskc    runlevel S 5, setenv INIT_HALT
 */

/**
 * This is what BSD 4.4 uses when talking to init.
 * Linux doesn't use this right now.
 */
struct init_request_bsd {
        char gen_id[8];         /* Beats me.. telnetd uses "fe" */
        char tty_id[16];        /* Tty name minus /dev/tty      */
        char host[INITRQ_HLEN]; /* Hostname                     */
        char term_type[16];     /* Terminal type                */
        int  signal;            /* Signal to send               */
        int  pid;               /* Process to send to           */
        char exec_name[128];    /* Program to execute           */
        char reserved[128];     /* For future expansion.        */
};

/**
 * Because of legacy interfaces, "runlevel" and "sleeptime" aren't in a
 * seperate struct in the union.
 *
 * The weird sizes are because init expects the whole struct to be 384 bytes.
 */
struct init_request {
        int magic;     /* Magic number               */
        int cmd;       /* What kind of request       */
        int runlevel;  /* Runlevel to change to      */
        int sleeptime; /* Time between TERM and KILL */
        union {
                struct init_request_bsd bsd;
                char  data[368];
        } i;
};

const char *telinit_map[0x100] = {
	/* not sure if these are mapped correctly */
	['0'] "runlevel poweroff",
	['1'] "runlevel single",
	['2'] "runlevel bare",
	['3'] "runlevel system",
	['5'] "runlevel user",
	['6'] "runlevel reboot",
	['s'] "runlevel single",
	['S'] "runlevel single",
	['q'] "reload",
	['Q'] "reload",
	['u'] "reload",
	['U'] "reload",
};

int open_initctl(char *init_fifo)
{
	/* First, try to create /dev/initctl if not present. */
	struct stat st, st2;
	if (stat(init_fifo, &st2) < 0 && errno == ENOENT)
		mkfifo(init_fifo, 0600);

	/* Now finally try to open /dev/initctl */
	int pipe_fd = open(init_fifo, O_RDWR);
	if (pipe_fd < 0)
		err(errno, "error opening %s", init_fifo);

	/* Make sure it's a fifo */
	fstat(pipe_fd, &st);
	if (!S_ISFIFO(st.st_mode)) {
		errno = EINVAL;
		err(errno, "%s is not a fifo", init_fifo);
	}

	return pipe_fd;
}

void process_request(struct init_request *request)
{
	if (request->sleeptime)
		printf("eval SLEEP_TIME=%d\n", request->sleeptime);

	switch (request->cmd) {
	case INIT_CMD_RUNLVL:
		if (telinit_map[request->runlevel])
			printf("%s\n", telinit_map[request->runlevel]);
		break;
	case INIT_CMD_POWERFAIL:
		printf("powerfail\n");
		break;
	case INIT_CMD_POWERFAILNOW:
		printf("powerfailnow\n");
		break;
	case INIT_CMD_POWEROK:
		printf("powerok\n");
		break;
	case INIT_CMD_SETENV:
		printf("eval export %.*s\n",
				(int)sizeof(request->i.data),
				request->i.data);
		break;
	case INIT_CMD_CHANGECONS:
		printf("changeconsole %.*s\n",
				(int)sizeof(request->i.bsd.reserved),
				request->i.bsd.reserved);
		break;
	default:
		fprintf(stderr, "got unimplemented initrequest");
		break;
	}
	fflush(stdout);
}

int main(int argc, char **argv)
{
	if (argc != 2) {
		printf("usage: %s <initctl>\n", argv[0]);
		return -EINVAL;
	}
	char *init_fifo = argv[1];
	int pipe_fd = open_initctl(init_fifo);

	/* Main loop, process data and reopen pipe when necessasairy */
	while (1) {
		/* Read the data, return on EINTR. */
		struct init_request request;
		int n = read(pipe_fd, &request, sizeof(request));
		if (n == 0)
			pipe_fd = open_initctl(init_fifo);
		else if (n <= 0)
		      warn("error reading request");
		else if (n != sizeof(request))
		      warn("short read");
		else if (request.magic != INIT_MAGIC)
		      warn("got bogus request");
		else
		      process_request(&request);
	}

	return 0;
}
