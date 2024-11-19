#include <iostream>
#include <cuda_runtime.h>

#define NUM_PRODUCTS 10000

// Kernel 1: Apply a moving average filter to distance data
__global__ void filter_distance(float *distances, float *filtered_distances, int N, int window_size) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < N) {
        float sum = 0.0f;
        int count = 0;
        for (int i = idx - window_size; i <= idx + window_size; i++) {
            if (i >= 0 && i < N) {
                sum += distances[i];
                count++;
            }
        }
        filtered_distances[idx] = sum / count;
    }
}

// Kernel 2: Apply a moving average filter to weight data
__global__ void filter_weight(float *weights, float *filtered_weights, int N, int window_size) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < N) {
        float sum = 0.0f;
        int count = 0;
        for (int i = idx - window_size; i <= idx + window_size; i++) {
            if (i >= 0 && i < N) {
                sum += weights[i];
                count++;
            }
        }
        filtered_weights[idx] = sum / count;
    }
}

// Kernel 3: Check distance thresholds
__global__ void check_distance_threshold(float *filtered_distances, int *distance_status, float min_dist, float max_dist, int N) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < N) {
        if (filtered_distances[idx] >= min_dist && filtered_distances[idx] <= max_dist) {
            distance_status[idx] = 1;  // Accepted
        } else {
            distance_status[idx] = 0;  // Rejected
        }
    }
}

// Kernel 4: Check weight thresholds
__global__ void check_weight_threshold(float *filtered_weights, int *weight_status, float min_weight, float max_weight, int N) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < N) {
        if (filtered_weights[idx] >= min_weight && filtered_weights[idx] <= max_weight) {
            weight_status[idx] = 1;  // Accepted
        } else {
            weight_status[idx] = 0;  // Rejected
        }
    }
}

// Kernel 5: Update product status based on distance and weight checks
__global__ void update_product_status(int *distance_status, int *weight_status, int *product_status, int N) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < N) {
        if (distance_status[idx] == 1 && weight_status[idx] == 1) {
            product_status[idx] = 1;  // Accepted
        } else {
            product_status[idx] = 0;  // Rejected
        }
    }
}

// Host code
int main() {
    const int size = NUM_PRODUCTS * sizeof(float);
    const int status_size = NUM_PRODUCTS * sizeof(int);

    // Allocate host memory
    float *h_distances = new float[NUM_PRODUCTS];
    float *h_weights = new float[NUM_PRODUCTS];
    float *h_filtered_distances = new float[NUM_PRODUCTS];
    float *h_filtered_weights = new float[NUM_PRODUCTS];
    int *h_distance_status = new int[NUM_PRODUCTS];
    int *h_weight_status = new int[NUM_PRODUCTS];
    int *h_product_status = new int[NUM_PRODUCTS];

    // Initialize random distance and weight data
    for (int i = 0; i < NUM_PRODUCTS; i++) {
        h_distances[i] = static_cast<float>(rand() % 100 + 50);  // Distance in cm
        h_weights[i] = static_cast<float>(rand() % 50 + 10);     // Weight in grams
    }

    // Allocate device memory
    float *d_distances, *d_weights, *d_filtered_distances, *d_filtered_weights;
    int *d_distance_status, *d_weight_status, *d_product_status;
    cudaMalloc((void **)&d_distances, size);
    cudaMalloc((void **)&d_weights, size);
    cudaMalloc((void **)&d_filtered_distances, size);
    cudaMalloc((void **)&d_filtered_weights, size);
    cudaMalloc((void **)&d_distance_status, status_size);
    cudaMalloc((void **)&d_weight_status, status_size);
    cudaMalloc((void **)&d_product_status, status_size);

    // Copy data from host to device
    cudaMemcpy(d_distances, h_distances, size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_weights, h_weights, size, cudaMemcpyHostToDevice);

    // Configure thread and block dimensions
    int blockSize = 256;
    int numBlocks = (NUM_PRODUCTS + blockSize - 1) / blockSize;

    // Launch kernel routines
    filter_distance<<<numBlocks, blockSize>>>(d_distances, d_filtered_distances, NUM_PRODUCTS, 3);
    filter_weight<<<numBlocks, blockSize>>>(d_weights, d_filtered_weights, NUM_PRODUCTS, 3);
    check_distance_threshold<<<numBlocks, blockSize>>>(d_filtered_distances, d_distance_status, 60.0f, 120.0f, NUM_PRODUCTS);
    check_weight_threshold<<<numBlocks, blockSize>>>(d_filtered_weights, d_weight_status, 15.0f, 40.0f, NUM_PRODUCTS);
    update_product_status<<<numBlocks, blockSize>>>(d_distance_status, d_weight_status, d_product_status, NUM_PRODUCTS);

    // Copy results back to host
    cudaMemcpy(h_filtered_distances, d_filtered_distances, size, cudaMemcpyDeviceToHost);
    cudaMemcpy(h_filtered_weights, d_filtered_weights, size, cudaMemcpyDeviceToHost);
    cudaMemcpy(h_product_status, d_product_status, status_size, cudaMemcpyDeviceToHost);

    // Print results
    for (int i = 0; i < 10; i++) {
        std::cout << "Product " << i << ": Distance = " << h_filtered_distances[i]
                  << " cm, Weight = " << h_filtered_weights[i]
                  << " g, Status = " << (h_product_status[i] ? "Accepted" : "Rejected") << std::endl;
    }

    // Free memory
    delete[] h_distances;
    delete[] h_weights;
    delete[] h_filtered_distances;
    delete[] h_filtered_weights;
    delete[] h_distance_status;
    delete[] h_weight_status;
    delete[] h_product_status;
    cudaFree(d_distances);
    cudaFree(d_weights);
    cudaFree(d_filtered_distances);
    cudaFree(d_filtered_weights);
    cudaFree(d_distance_status);
    cudaFree(d_weight_status);
    cudaFree(d_product_status);

    return 0;
}

