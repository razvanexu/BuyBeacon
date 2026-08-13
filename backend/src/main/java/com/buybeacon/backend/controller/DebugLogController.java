package com.buybeacon.backend.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.time.format.DateTimeFormatter;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;

/**
 * Temporary debug-log sink for on-device diagnosis of the location-tracking
 * issues (see CLAUDE.md "Map/shop list never refreshed while roaming").
 * Lets the app POST its DebugFileLogger lines here in near-real-time over
 * the internet (not just home Wi-Fi), instead of requiring an adb pull
 * after every walk. In-memory only, capped ring buffer -- not for
 * long-term storage. Remove once the location-tracking investigation is
 * closed out.
 */
@RestController
@RequestMapping("/api/debug/log")
public class DebugLogController {

    private static final int MAX_ENTRIES = 5000;
    private static final DateTimeFormatter TIMESTAMP_FORMAT = DateTimeFormatter.ISO_INSTANT;

    private final Deque<LogEntry> entries = new ArrayDeque<>(MAX_ENTRIES);

    @Value("${debug.log.token:}")
    private String configuredToken;

    private record LogEntry(String receivedAt, String message) {}

    public record LogRequest(String message) {}

    @PostMapping
    public synchronized ResponseEntity<Void> append(
            @RequestHeader(value = "X-Debug-Token", required = false) String token,
            @RequestBody LogRequest request) {
        if (!isAuthorized(token)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        if (request == null || request.message() == null || request.message().isBlank()) {
            return ResponseEntity.badRequest().build();
        }

        if (entries.size() >= MAX_ENTRIES) {
            entries.removeFirst();
        }
        entries.addLast(new LogEntry(TIMESTAMP_FORMAT.format(Instant.now()), request.message()));
        return ResponseEntity.ok().build();
    }

    @GetMapping
    public synchronized ResponseEntity<String> read(
            @RequestHeader(value = "X-Debug-Token", required = false) String token) {
        if (!isAuthorized(token)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        List<String> lines = new ArrayList<>(entries.size());
        for (LogEntry entry : entries) {
            lines.add(entry.receivedAt() + " " + entry.message());
        }
        return ResponseEntity.ok(String.join("\n", lines));
    }

    @DeleteMapping
    public synchronized ResponseEntity<Void> clear(
            @RequestHeader(value = "X-Debug-Token", required = false) String token) {
        if (!isAuthorized(token)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        entries.clear();
        return ResponseEntity.ok().build();
    }

    private boolean isAuthorized(String token) {
        return configuredToken != null && !configuredToken.isBlank() && configuredToken.equals(token);
    }
}
