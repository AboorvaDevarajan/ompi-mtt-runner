#include <mpi.h>
#include <stdio.h>

int main(int argc, char **argv) {
    MPI_Init(&argc, &argv);
    printf("MPI_Init succeeded\n");
    MPI_Finalize();
    printf("MPI_Finalize succeeded\n");
    return 0;
}
