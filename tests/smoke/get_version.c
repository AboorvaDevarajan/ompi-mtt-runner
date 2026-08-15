#include <mpi.h>
#include <stdio.h>

int main(int argc, char **argv) {
    int version, subversion;
    MPI_Get_version(&version, &subversion);
    printf("MPI version: %d.%d\n", version, subversion);
    return 0;
}
