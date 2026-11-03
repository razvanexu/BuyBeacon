package com.buybeacon.backend.service;

import com.buybeacon.backend.client.OpenStreetMapOverpassClient;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class OpenStreetMapPhysicalStoreDiscoveryServiceTest {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Mock
    private OpenStreetMapOverpassClient overpassClient;

    private OpenStreetMapPhysicalStoreDiscoveryService service;

    @BeforeEach
    void setUp() {
        service = new OpenStreetMapPhysicalStoreDiscoveryService(overpassClient, true, 2_000, 10, 120);
    }

    @Test
    void findsOnlyCustomerFacingPhysicalHardwareStores_andSortsByDistance() throws Exception {
        when(overpassClient.execute(anyString())).thenReturn(objectMapper.readTree("""
                {"elements":[
                  {"type":"node","id":1,"lat":44.4100,"lon":26.1100,
                   "tags":{"shop":"hardware","name":"Feroneria departe"}},
                  {"type":"way","id":2,"center":{"lat":44.4010,"lon":26.1010},
                   "tags":{"shop":"doityourself","name":"Brico aproape"}},
                  {"type":"node","id":3,"lat":44.4020,"lon":26.1020,
                   "tags":{"shop":"hardware","name":"Depozit","warehouse":"yes"}},
                  {"type":"node","id":4,"lat":44.4030,"lon":26.1030,
                   "tags":{"shop":"hardware","name":"Magazin privat","access":"private"}},
                  {"type":"node","id":5,"lat":44.4040,"lon":26.1040,
                   "tags":{"shop":"hardware","name":"Fost magazin","disused":"yes"}},
                  {"type":"node","id":6,"lat":44.4050,"lon":26.1050,
                   "tags":{"office":"company","name":"Sediu"}}
                ]}
                """));

        List<PhysicalStoreCandidate> result = service.findNearby("hardware_store", 44.4, 26.1);

        assertEquals(2, result.size());
        assertEquals("Brico aproape", result.get(0).name());
        assertEquals("osm:way:2", result.get(0).sourceId());
        assertEquals("Feroneria departe", result.get(1).name());
        assertTrue(result.stream().allMatch(shop -> shop.source().equals("openstreetmap")));
    }

    @Test
    void includesAmenityPharmacies_andGivesUnnamedStoresAHonestLabel() throws Exception {
        when(overpassClient.execute(anyString())).thenReturn(objectMapper.readTree("""
                {"elements":[
                  {"type":"node","id":7,"lat":44.4,"lon":26.1,
                   "tags":{"amenity":"pharmacy"}}
                ]}
                """));

        List<PhysicalStoreCandidate> result = service.findNearby("pharmacy", 44.4, 26.1);

        assertEquals(1, result.size());
        assertEquals("Farmacie", result.get(0).name());
        assertEquals("pharmacy", result.get(0).storeType());
    }

    @Test
    void buildsABoundedCategoryQuery() {
        String query = service.buildQuery("hardware_store", Set.of("hardware", "doityourself"), 44.4, 26.1);

        assertTrue(query.contains("[timeout:10]"));
        assertTrue(query.contains("around:2000,44.4,26.1"));
        assertTrue(query.contains("doityourself|hardware"));
        assertTrue(query.endsWith("out center tags;"));
    }

    @Test
    void reusesShortLivedCacheForSameAreaAndCategory() throws Exception {
        when(overpassClient.execute(anyString())).thenReturn(objectMapper.readTree("{\"elements\":[]}"));

        service.findNearby("supermarket", 44.40001, 26.10001);
        service.findNearby("supermarket", 44.40002, 26.10002);

        verify(overpassClient, times(1)).execute(anyString());
    }

    @Test
    void returnsEmptyWhenOverpassIsUnavailableOrCategoryIsUnknown() {
        when(overpassClient.execute(anyString())).thenThrow(new RuntimeException("timeout"));

        assertTrue(service.findNearby("supermarket", 44.4, 26.1).isEmpty());
        assertTrue(service.findNearby("unknown", 44.4, 26.1).isEmpty());
    }
}
