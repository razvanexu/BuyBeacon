package com.buybeacon.backend.scraper;

import org.jsoup.Jsoup;
import org.springframework.stereotype.Component;

import java.io.IOException;

/**
 * A JSoup-based implementation of the HtmlFetcher interface.
 */
@Component
public class JSoupHtmlFetcher implements HtmlFetcher {
    @Override
    public String fetchHtml(String url) throws IOException {
        // Connect to the URL, get the document, and return its full HTML content as a string.
        //Use a user-agent to mimic a real browser.
        return Jsoup.connect(url)
                .userAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.11")
                .get()
                .outerHtml();
    }
}
