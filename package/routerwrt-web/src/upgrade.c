/*
 * RouterWRT firmware upgrade CGI
 *
 * Endpoints:
 *
 *   POST /cgi-bin/upgrade.cgi
 *     multipart/form-data
 *     field name: firmware
 *
 *   POST /cgi-bin/upgrade.cgi?action=flash&keep=1
 *
 *   POST /cgi-bin/upgrade.cgi?action=flash&keep=0
 *
 * Uploaded image:
 *   /tmp/routerwrt-sysupgrade.bin
 *
 * Compile:
 *   $(TARGET_CC) -Os -Wall -Wextra -o upgrade.cgi upgrade.c
 */

#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>

#define UPLOAD_FILE "/tmp/routerwrt-sysupgrade.bin"

/*
 * Adjust this for the largest image your target can reasonably accept.
 *
 * RT305x sysupgrade images are small, so 16 MiB is already generous.
 */
#define MAX_UPLOAD (16 * 1024 * 1024)

static void
json_header(void)
{
    printf("Content-Type: application/json\r\n");
    printf("Cache-Control: no-store\r\n");
    printf("\r\n");
}

static void
json_error(const char *msg)
{
    json_header();
    printf("{\"ok\":false,\"error\":\"%s\"}\n", msg);
}

static void
json_ok(const char *msg)
{
    json_header();
    printf("{\"ok\":true,\"message\":\"%s\"}\n", msg);
}


/*
 * Execute a command directly.
 *
 * No shell.
 * No system().
 * No user supplied command strings.
 */
static int
run_command(char *const argv[])
{
    pid_t pid;
    int status;

    pid = fork();

    if (pid < 0)
        return -1;

    if (pid == 0) {
        execv(argv[0], argv);
        _exit(127);
    }

    if (waitpid(pid, &status, 0) < 0)
        return -1;

    if (!WIFEXITED(status))
        return -1;

    return WEXITSTATUS(status);
}


/*
 * Search binary memory for a byte sequence.
 *
 * Similar to strstr(), but works when data is not NUL terminated.
 */
static unsigned char *
memfind(unsigned char *haystack,
        size_t haystack_len,
        const unsigned char *needle,
        size_t needle_len)
{
    size_t i;

    if (!needle_len || haystack_len < needle_len)
        return NULL;

    for (i = 0; i <= haystack_len - needle_len; i++) {
        if (!memcmp(haystack + i, needle, needle_len))
            return haystack + i;
    }

    return NULL;
}


/*
 * Extract:
 *
 * boundary=------------------------abcdef
 *
 * from CONTENT_TYPE.
 */
static int
get_boundary(const char *content_type,
             char *boundary,
             size_t boundary_size)
{
    const char *p;
    size_t len;

    if (!content_type)
        return -1;

    if (strncmp(content_type,
                "multipart/form-data",
                strlen("multipart/form-data")) != 0)
        return -1;

    p = strstr(content_type, "boundary=");

    if (!p)
        return -1;

    p += strlen("boundary=");

    /*
     * Handle quoted boundary.
     */
    if (*p == '"') {
        const char *end;

        p++;
        end = strchr(p, '"');

        if (!end)
            return -1;

        len = end - p;
    } else {
        const char *end = strchr(p, ';');

        if (end)
            len = end - p;
        else
            len = strlen(p);
    }

    if (!len || len + 1 > boundary_size)
        return -1;

    memcpy(boundary, p, len);
    boundary[len] = '\0';

    return 0;
}


/*
 * Very small multipart parser.
 *
 * Expected request:
 *
 * --boundary
 * Content-Disposition: form-data; name="firmware"; filename="foo.bin"
 * Content-Type: application/octet-stream
 *
 * <binary firmware>
 * --boundary--
 *
 *
 * For a firmware CGI this is deliberately narrower than a general-purpose
 * multipart implementation.
 */
static int
handle_upload(void)
{
    const char *content_type;
    const char *length_str;

    long content_length;

    char boundary[256];
    char marker[300];

    unsigned char *body;
    unsigned char *header_end;
    unsigned char *data_start;
    unsigned char *data_end;

    size_t marker_len;
    size_t firmware_len;

    int fd;
    ssize_t n;
    size_t received = 0;

    char *validate_argv[] = {
        "/sbin/sysupgrade",
        "-T",
        UPLOAD_FILE,
        NULL
    };

    content_type = getenv("CONTENT_TYPE");
    length_str   = getenv("CONTENT_LENGTH");

    if (!length_str) {
        json_error("missing content length");
        return 1;
    }

    content_length = strtol(length_str, NULL, 10);

    if (content_length <= 0 ||
        content_length > MAX_UPLOAD) {

        json_error("invalid upload size");
        return 1;
    }

    if (get_boundary(content_type,
                     boundary,
                     sizeof(boundary)) < 0) {

        json_error("invalid multipart request");
        return 1;
    }

    body = malloc((size_t)content_length);

    if (!body) {
        json_error("not enough memory");
        return 1;
    }

    /*
     * Read request body from CGI stdin.
     */
    while (received < (size_t)content_length) {

        n = read(STDIN_FILENO,
                 body + received,
                 (size_t)content_length - received);

        if (n < 0) {
            if (errno == EINTR)
                continue;

            free(body);
            json_error("failed reading upload");
            return 1;
        }

        if (n == 0)
            break;

        received += n;
    }

    if (received != (size_t)content_length) {
        free(body);
        json_error("incomplete upload");
        return 1;
    }

    /*
     * Find end of multipart headers.
     */
    header_end = memfind(
        body,
        received,
        (const unsigned char *)"\r\n\r\n",
        4
    );

    if (!header_end) {
        free(body);
        json_error("invalid multipart headers");
        return 1;
    }

    /*
     * Require our expected field.
     */
    {
        size_t header_len =
            (size_t)(header_end - body);

        if (!memfind(body,
                     header_len,
                     (const unsigned char *)
                     "name=\"firmware\"",
                     strlen("name=\"firmware\""))) {

            free(body);
            json_error("firmware field missing");
            return 1;
        }
    }

    data_start = header_end + 4;

    /*
     * Multipart terminator before the boundary is:
     *
     * \r\n--BOUNDARY
     */
    snprintf(marker,
             sizeof(marker),
             "\r\n--%s",
             boundary);

    marker_len = strlen(marker);

    data_end = memfind(
        data_start,
        received - (size_t)(data_start - body),
        (const unsigned char *)marker,
        marker_len
    );

    if (!data_end) {
        free(body);
        json_error("multipart boundary missing");
        return 1;
    }

    firmware_len =
        (size_t)(data_end - data_start);

    if (!firmware_len) {
        free(body);
        json_error("empty firmware image");
        return 1;
    }

    /*
     * /tmp is RAM on the router.
     *
     * Use a restrictive mode.
     */
    fd = open(UPLOAD_FILE,
              O_WRONLY |
              O_CREAT |
              O_TRUNC,
              0600);

    if (fd < 0) {
        free(body);
        json_error("cannot create temporary image");
        return 1;
    }

    {
        size_t done = 0;

        while (done < firmware_len) {

            n = write(fd,
                      data_start + done,
                      firmware_len - done);

            if (n < 0) {

                if (errno == EINTR)
                    continue;

                close(fd);
                unlink(UPLOAD_FILE);
                free(body);

                json_error("failed writing image");
                return 1;
            }

            done += n;
        }
    }

    close(fd);
    free(body);

    /*
     * Existing RouterWRT/OpenWrt sysupgrade machinery performs the real
     * compatibility test.
     */
    if (run_command(validate_argv) != 0) {

        unlink(UPLOAD_FILE);

        json_error("firmware validation failed");
        return 1;
    }

    /*
     * Return size so the UI can show something useful.
     */
    json_header();

    printf(
        "{\"ok\":true,"
        "\"message\":\"firmware image valid\","
        "\"size\":%lu}\n",
        (unsigned long)firmware_len
    );

    return 0;
}


static int
handle_flash(int keep_config)
{
    struct stat st;

    char *keep_argv[] = {
        "/sbin/sysupgrade",
        UPLOAD_FILE,
        NULL
    };

    char *erase_argv[] = {
        "/sbin/sysupgrade",
        "-n",
        UPLOAD_FILE,
        NULL
    };

    if (stat(UPLOAD_FILE, &st) < 0) {
        json_error("no firmware image uploaded");
        return 1;
    }

    /*
     * Tell browser before sysupgrade kills services/network.
     */
    json_header();

    printf(
        "{\"ok\":true,"
        "\"message\":\"upgrade starting\"}\n"
    );

    fflush(stdout);

    /*
     * sysupgrade should replace this CGI process.
     *
     * No shell involved.
     */
    if (keep_config)
        execv(keep_argv[0], keep_argv);
    else
        execv(erase_argv[0], erase_argv);

    /*
     * We only reach this if exec failed.
     */
    return 1;
}


static int
query_has(const char *query,
          const char *needle)
{
    if (!query)
        return 0;

    return strstr(query, needle) != NULL;
}


int
main(void)
{
    const char *method;
    const char *query;

    method = getenv("REQUEST_METHOD");
    query  = getenv("QUERY_STRING");

    if (!method ||
        strcmp(method, "POST") != 0) {

        json_error("POST required");
        return 1;
    }

    /*
     * Flash operation:
     *
     *   ?action=flash&keep=1
     */
    if (query_has(query, "action=flash")) {

        int keep_config =
            !query_has(query, "keep=0");

        return handle_flash(keep_config);
    }

    /*
     * Otherwise POST means firmware upload.
     */
    return handle_upload();
}
