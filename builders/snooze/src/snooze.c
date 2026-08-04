/*
 * snooze - minimal static HTTP server.
 *
 * Listens on 0.0.0.0:8080 and answers every request with a fixed message.
 * Built fully static so it runs on any base without shared libraries.
 */
#include <arpa/inet.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#define PORT 8080
#define BACKLOG 16
#define MESSAGE "OK\n"

static void handle_client(int fd) {
    char buf[4096];
    ssize_t n;

    /* Drain the request headers (best effort). */
    while ((n = read(fd, buf, sizeof(buf))) > 0) {
        if (memmem(buf, (size_t)n, "\r\n\r\n", 4) != NULL)
            break;
    }

    const char *response =
        "HTTP/1.1 200 OK\r\n"
        "Content-Type: text/plain\r\n"
        "Content-Length: 3\r\n"
        "Connection: close\r\n"
        "\r\n"
        MESSAGE;

    (void)write(fd, response, strlen(response));
    close(fd);
}

int main(void) {
    int server_fd;
    struct sockaddr_in addr;

    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        perror("socket");
        return 1;
    }

    int one = 1;
    (void)setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));

    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = htons(PORT);

    if (bind(server_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind");
        return 1;
    }
    if (listen(server_fd, BACKLOG) < 0) {
        perror("listen");
        return 1;
    }

    for (;;) {
        int client_fd = accept(server_fd, NULL, NULL);
        if (client_fd < 0) {
            perror("accept");
            continue;
        }
        handle_client(client_fd);
    }
}
