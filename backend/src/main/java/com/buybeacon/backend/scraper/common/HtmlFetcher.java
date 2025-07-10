package com.buybeacon.backend.scraper.common;

import java.io.IOException;

/**
 * An interface for fetching the raw HTML content from a given URL.
 * This abstraction allows for swapping the underlying HTTP client (e.g., Jsoup, HttpClient)
 8  * without changing the scraper logic.
 */
public interface HtmlFetcher {
    /**
     * Fetches the HTML content of a web page.
     *
     * @param url The URL of the page to fetch.
     * @return The raw HTML content of the page as a String.
     * @throws IOException if a network error occurs.
     */
    String fetchHtml(String url) throws IOException;
}
