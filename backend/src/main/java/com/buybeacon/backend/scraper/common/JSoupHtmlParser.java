package com.buybeacon.backend.scraper.common;

import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.select.Elements;
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

    @Override
    public List<Map<String, String>> parseHtml(String rawHtml, String itemSelector, Map<String, String> attributeSelectors, Map<String, String> urlAttribute) {
        Document doc = Jsoup.parse(rawHtml);
        Elements items = doc.select(itemSelector);
        List<Map<String, String>> parsedData = new ArrayList<>();

        for (Element item : items){
            Map<String, String> itemData = new HashMap<>();
            boolean allAttributesFound = true;

            // Extract standard text attributes
            allAttributesFound = isAllAttributesFound(attributeSelectors, item, itemData, allAttributesFound);

            if (!allAttributesFound) continue;

            // Extract URL attributes
            allAttributesFound = isAttributesFound(urlAttribute, item, itemData, allAttributesFound);

            if(allAttributesFound){
                parsedData.add(itemData);
            }
        }
        return parsedData;
    }

    private static boolean isAttributesFound(Map<String, String> urlAttribute, Element item, Map<String, String> itemData, boolean allAttributesFound) {
        for(Map.Entry<String, String> entry : urlAttribute.entrySet()){
            String attributeName = entry.getKey();
            String selector = entry.getValue();
            Element element = item.selectFirst(selector);

            if (element != null) {
                itemData.put(attributeName, element.attr("href"));
            } else {
                allAttributesFound = false;
                break;
            }
        }
        return allAttributesFound;
    }

    private static boolean isAllAttributesFound(Map<String, String> attributeSelectors, Element item, Map<String, String> itemData, boolean allAttributesFound) {
        for (Map.Entry<String, String> entry : attributeSelectors.entrySet()){
            String attributeName = entry.getKey();
            String selector = entry.getValue();
            Element element = item.selectFirst(selector);

            if (element != null){
                if ("price".equals(attributeName) && element.hasAttr("data-price-ammount")){
                    itemData.put(attributeName, element.attr("data-price-ammount"));
                }else {
                    itemData.put(attributeName, element.text());
                }
            }else {
                allAttributesFound = false;
                break;
            }
        }
        return allAttributesFound;
    }
}
