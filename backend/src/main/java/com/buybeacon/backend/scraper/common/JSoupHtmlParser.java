package com.buybeacon.backend.scraper.common;

import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.select.Elements;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * A Jsoup-based implementation of the HtmlParser interface.
 * This is the only class that should contain Jsoup-specific parsing logic.
 */
@Component
public class JSoupHtmlParser implements HtmlParser {
    private static final Logger logger = LoggerFactory.getLogger(JSoupHtmlParser.class);

    @Override
    public List<Map<String, String>> parseHtml(String rawHtml, String itemSelector, Map<String, String> attributeSelectors, Map<String, String> urlAttribute) {
        Document doc = Jsoup.parse(rawHtml);
        Elements items = doc.select(itemSelector);
        List<Map<String, String>> parsedData = new ArrayList<>();

        for (Element item : items){
            Map<String, String> itemData = new HashMap<>();
            boolean allAttributesFound = true;

            for (Map.Entry<String, String> entry : attributeSelectors.entrySet()){
                String key = entry.getKey();
                String selector = entry.getValue();
                Element element = item.selectFirst(selector);

                if (element != null) {
                    String extractedText;
                    // Special handling for price attribute on some sites (retained for flexibility)
                    if ("price".equals(key) && element.hasAttr("data-price-amount")) {
                            extractedText = element.attr("data-price-amount");
                        } else {
                            extractedText = element.text();
                        }
                        // --- Data Cleaning and Validation Step for shop names ---
                    if ("name".equals(key) && !isValidShopName(extractedText)) {
                            logger.warn("Filtered out invalid or non-store result: {}", extractedText);
                            allAttributesFound = false;
                            break; // Skip this item entirely if the name is invalid
                        }
                    itemData.put(key, extractedText);
                    } else {
                    allAttributesFound = false;
                    break;
                }
            }

            if (!allAttributesFound) continue;

            // Extract URL attributes
            for (Map.Entry<String, String> entry : urlAttribute.entrySet()) {
                    String key = entry.getKey();
                    String selector = entry.getValue();
                    Element element = item.selectFirst(selector);
                    if (element != null) {
                            itemData.put(key, element.attr("href"));
                        } else {
                            allAttributesFound = false;
                            break;
                        }
                }
                if (allAttributesFound) {
                    parsedData.add(itemData);
                }
            }
        return parsedData;
    }

    /**
     * Validates if the extracted text is likely a real store name.
     * @param shopName The text extracted from the search result.
     * @return true if the name is considered valid, false otherwise.
     */
     private boolean isValidShopName(String shopName) {
        if (shopName == null || shopName.isBlank()) {
                return false;
            }
        // Filter out results that are clearly URLs or contain URL-like text
         // or are too long to be a simple store name
        if (shopName.contains(".ro") || shopName.contains(".com")
                || shopName.contains("http") || shopName.contains("www")
                || shopName.length() > 100) {
                return false;
            }
        // Add any other filtering rules you discover here
         return true;
     }
}
