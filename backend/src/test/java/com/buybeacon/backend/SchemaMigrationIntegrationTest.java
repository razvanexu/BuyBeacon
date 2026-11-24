package com.buybeacon.backend;

import com.buybeacon.backend.client.GooglePlacesClient;
import com.buybeacon.backend.service.WebSearchService;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationInfo;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import java.util.Arrays;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
class SchemaMigrationIntegrationTest {

    @Autowired
    private Flyway flyway;

    @Value("${spring.jpa.hibernate.ddl-auto}")
    private String ddlAuto;

    @MockitoBean
    private WebSearchService webSearchService;

    @MockitoBean
    private GooglePlacesClient googlePlacesClient;

    @Test
    void baselineMigrationIsApplied() {
        assertThat(Arrays.stream(flyway.info().applied()).map(MigrationInfo::getVersion).map(Object::toString))
                .contains("1");
        assertThat(flyway.info().pending()).isEmpty();
    }

    @Test
    void hibernateOnlyValidatesTheSchema() {
        assertThat(ddlAuto).isEqualTo("validate");
    }
}
