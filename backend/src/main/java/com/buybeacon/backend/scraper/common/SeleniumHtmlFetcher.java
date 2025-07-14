package com.buybeacon.backend.scraper.common;

import org.openqa.selenium.WebDriver;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.chrome.ChromeOptions;
import org.springframework.context.annotation.Primary;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.util.Collections;

@Component
@Primary
@Profile("!test")
public class SeleniumHtmlFetcher implements HtmlFetcher {

    @Override
    public String fetchHtml(String url) throws IOException {

        WebDriver driver = null;
        try {
                driver = createWebDriver();
                driver.get(url);
                try {
                        Thread.sleep(2000);
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                    }
                return driver.getPageSource();
            } finally {
                if (driver != null) {
                        driver.quit();
                    }
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
