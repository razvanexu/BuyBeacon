package com.buybeacon.backend.controller;

import com.buybeacon.backend.scraper.common.Product;
import com.buybeacon.backend.scraper.orchestration.ScraperOrchestrator;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.io.IOException;
import java.util.List;

@RestController
@RequestMapping("/api/scrape")
public class ScraperController {
    private ScraperOrchestrator scraperOrchestrator;

    @Autowired
    public ScraperController(ScraperOrchestrator scraperOrchestrator) {
        this.scraperOrchestrator = scraperOrchestrator;
    }

    @GetMapping("/products")
    public List<Product> getProducts(@RequestParam String query, @RequestParam String retailerName) throws IOException {
        return scraperOrchestrator.scrapeProducts(query, retailerName);
    }
}
