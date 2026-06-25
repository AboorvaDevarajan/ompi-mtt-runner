#include <mpi.h>
#include <stdio.h>

int main(int argc, char **argv) {
    MPI_Init(&argc, &argv);
    int rank, value = 0;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    if (rank == 0) value = 42;
    MPI_Bcast(&value, 1, MPI_INT, 0, MPI_COMM_WORLD);
    printf("Rank %d got value %d\n", rank, value);
    if (value != 42) {
        MPI_Finalize();
        return 1;
    }
    MPI_Finalize();
    return 0;
}
