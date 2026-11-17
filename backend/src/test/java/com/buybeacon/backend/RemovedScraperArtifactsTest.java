package com.buybeacon.backend;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;

/**
 * Guards the 2026-11-17 removal of the Carrefour scraper and Selenium: none of the removed
 * classes, libraries or deployment pieces may come back (directly or as a transitive dependency).
 */
class RemovedScraperArtifactsTest {

    @ParameterizedTest
    @ValueSource(strings = {
            "com.buybeacon.backend.scraper.retailers.CarrefourScraper",
            "com.buybeacon.backend.scraper.orchestration.ScraperOrchestrator",
            "com.buybeacon.backend.scraper.orchestration.RetailerScraper",
            "com.buybeacon.backend.scraper.common.SeleniumHtmlFetcher",
            "com.buybeacon.backend.scraper.common.JSoupHtmlFetcher",
            "com.buybeacon.backend.scraper.common.JSoupHtmlParser",
            "com.buybeacon.backend.controller.ScraperController",
    })
    void removedApplicationClassesAreGone(String className) {
        assertThrows(ClassNotFoundException.class, () -> Class.forName(className));
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "org.openqa.selenium.WebDriver",            // selenium-java
            "org.openqa.selenium.remote.RemoteWebDriver",
            "org.jsoup.Jsoup",                          // jsoup
    })
    void removedLibrariesAreNotOnTheClasspath(String className) {
        assertThrows(ClassNotFoundException.class, () -> Class.forName(className));
    }

    @Test
    void dockerComposeNoLongerStartsSelenium() throws IOException {
        // Surefire runs with the backend module as working directory.
        String compose = Files.readString(Path.of("docker-compose.yml"));

        assertFalse(compose.toLowerCase().contains("selenium"),
                "docker-compose.yml must not define or reference a selenium service");
    }

    @Test
    void applicationPropertiesNoLongerConfigureSelenium() throws IOException {
        String mainProps = Files.readString(Path.of("src/main/resources/application.properties"));
        String testProps = Files.readString(Path.of("src/test/resources/application.properties"));

        assertFalse(mainProps.contains("selenium"), "main application.properties still mentions selenium");
        assertFalse(testProps.contains("selenium"), "test application.properties still mentions selenium");
    }
}
