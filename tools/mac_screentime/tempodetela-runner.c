/* Lancador do tempodetela.py para o launchd.
 * O Acesso Total ao Disco e concedido a ESTE binario; o Python roda como processo filho e herda a permissao.
 * Compilar: clang -O2 -o tempodetela-runner tempodetela-runner.c && codesign -s - -i online.cesaroliveira.tempodetela-runner -f tempodetela-runner
 * (recompilar muda a assinatura: remova e adicione de novo no Acesso Total ao Disco) */
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
extern char **environ;
#define PY "/Applications/Xcode.app/Contents/Developer/Library/Frameworks/Python3.framework/Versions/3.9/bin/python3.9"
#define SCRIPT "/Users/cesaroliveira/Scripts/tempodetela/tempodetela.py"
int main(int argc, char **argv) {
    char **a = calloc(argc + 2, sizeof(char *));
    a[0] = PY; a[1] = SCRIPT;
    for (int i = 1; i < argc; i++) a[i + 1] = argv[i];
    pid_t pid; int st;
    int rc = posix_spawn(&pid, PY, NULL, NULL, a, environ);
    if (rc != 0) { fprintf(stderr, "tempodetela-runner: posix_spawn falhou (%d)\n", rc); return 70; }
    if (waitpid(pid, &st, 0) < 0) return 71;
    return WIFEXITED(st) ? WEXITSTATUS(st) : 72;
}
