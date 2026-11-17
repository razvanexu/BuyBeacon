package com.buybeacon.backend.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Bounded thread pool for per-product shop discovery. Kept small on purpose: each
 * task fans out into several Google Places and Overpass requests, so unbounded
 * concurrency would burst outbound traffic from the backend's single IP.
 */
@Configuration
public class ScrapingConfig {

    private static final int MAX_CONCURRENT_SCRAPES = 3;

    @Bean(destroyMethod = "shutdown")
    public ExecutorService scrapingExecutor() {
        return Executors.newFixedThreadPool(MAX_CONCURRENT_SCRAPES);
    }
}
