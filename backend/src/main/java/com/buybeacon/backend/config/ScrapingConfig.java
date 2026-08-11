package com.buybeacon.backend.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Bounded thread pool shared by the shop-finding flow (web search, geocoding).
 * Kept small on purpose: each web-search task can spin up its own headless Chrome
 * instance, so unbounded concurrency would exhaust local resources and risk
 * looking like abusive traffic to Google.
 */
@Configuration
public class ScrapingConfig {

    private static final int MAX_CONCURRENT_SCRAPES = 3;

    @Bean(destroyMethod = "shutdown")
    public ExecutorService scrapingExecutor() {
        return Executors.newFixedThreadPool(MAX_CONCURRENT_SCRAPES);
    }
}
