package com.buybeacon.backend.scraper.common;

import org.openqa.selenium.JavascriptExecutor;
import org.openqa.selenium.TimeoutException;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebDriverException;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.chrome.ChromeOptions;
import org.openqa.selenium.support.ui.WebDriverWait;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Primary;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.time.Duration;
import java.util.Collections;

@Component
@Primary
@Profile("!test")
public class SeleniumHtmlFetcher implements HtmlFetcher {

    private static final Logger logger = LoggerFactory.getLogger(SeleniumHtmlFetcher.class);
    private static final Duration PAGE_LOAD_TIMEOUT = Duration.ofSeconds(15);
    private static final Duration READY_STATE_TIMEOUT = Duration.ofSeconds(5);

    @Override
    public String fetchHtml(String url) throws IOException {
        WebDriver driver = null;
        try {
            driver = createWebDriver();
            driver.manage().timeouts().pageLoadTimeout(PAGE_LOAD_TIMEOUT);
            driver.get(url);
            waitForPageReady(driver);
            return driver.getPageSource();
        } catch (WebDriverException e) {
            // Selenium throws unchecked exceptions (driver crash, timeout, etc.).
            // Wrap them so callers' existing IOException handling can react gracefully.
            throw new IOException("Failed to fetch HTML via Selenium for url: " + url, e);
        } finally {
            if (driver != null) {
                driver.quit();
            }
        }
    }

    private void waitForPageReady(WebDriver driver) {
        try {
            new WebDriverWait(driver, READY_STATE_TIMEOUT).until(webDriver ->
                    "complete".equals(((JavascriptExecutor) webDriver)
                            .executeScript("return document.readyState")));
        } catch (TimeoutException e) {
            logger.warn("Page did not reach 'complete' readyState within {}s, proceeding with current content.",
                    READY_STATE_TIMEOUT.getSeconds());
        }
    }

    private WebDriver createWebDriver(){
        ChromeOptions options = new ChromeOptions();

        options.addArguments("--disable-blink-features=AutomationControlled");
        options.setExperimentalOption("excludeSwitches", Collections.singletonList("enable-automation"));
        options.setExperimentalOption("useAutomationExtension", false);

        options.addArguments("--headless");
        options.addArguments("--disable-gpu");
        options.addArguments("--window-size=1920,1200");
        options.addArguments("--ignore-certificate-errors");
        options.addArguments("--no-sandbox");
        options.addArguments("--disable-dev-shm-usage");
        options.addArguments("--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" +
                "(KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36");

        return new ChromeDriver(options);
    }
}
