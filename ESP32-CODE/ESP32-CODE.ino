/*
 * ╔══════════════════════════════════════════════════════════════════╗
 * ║         SAFE-NET AUDITOR  —  ESP32 Firmware  v1.1               ║
 * ║  802.11 Management Frame Sniffer → JSON Serial @ 115200 baud    ║
 * ║                                                                  ║
 * ║  BOARD  : ESP32 DevKit V1 (any ESP32)                           ║
 * ║  LIBS   : ArduinoJson 6.x  (install via Library Manager)        ║
 * ║  WIRING : USB-C → Android OTG adapter → Phone                  ║
 * ╚══════════════════════════════════════════════════════════════════╝
 *
 * OUTPUT (every 1 second, newline-terminated JSON):
 * {
 *   "timestamp": 1234,
 *   "packets_per_sec": 142,
 *   "deauths": 3,
 *   "disassocs": 0,
 *   "probe_reqs": 5,
 *   "channel_congestion": [12,5,0,0,1,45,0,0,0,0,18,2,0],
 *   "deauth_targets": ["A1:B2:C3:D4:E5:F6", "B1:C2:D3:E4:F5:A6"],
 *   "networks": [
 *     {"ssid":"Campus_WiFi","bssid":"A1:B2:C3:D4:E5:F6",
 *      "rssi":-45,"channel":6,"oui_vendor":"TP-Link","frames":12}
 *   ]
 * }
 */

#include <Arduino.h>
#include <WiFi.h>
#include "esp_wifi.h"
#include "esp_wifi_types.h"
#include <ArduinoJson.h>

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════
#define SERIAL_BAUD          115200
#define JSON_INTERVAL_MS     1000
#define CHANNEL_HOP_MS       60
#define MAX_NETWORKS         25
#define MAX_SSID_LEN         32
#define NETWORK_EXPIRE_SEC   30
#define DEAUTH_BUF_SIZE      32        // ring buffer for deauth BSSIDs

// ═══════════════════════════════════════════════════════════════════════════════
// 802.11 FRAME DEFINITIONS
// ═══════════════════════════════════════════════════════════════════════════════
#define FC_TYPE(fc)          (((fc) >> 2) & 0x03)
#define FC_SUBTYPE(fc)       (((fc) >> 4) & 0x0F)

#define FRAME_TYPE_MGMT      0x00

#define SUBTYPE_ASSOC_REQ    0x00
#define SUBTYPE_ASSOC_RESP   0x01
#define SUBTYPE_PROBE_REQ    0x04
#define SUBTYPE_PROBE_RESP   0x05
#define SUBTYPE_BEACON       0x08
#define SUBTYPE_DISASSOC     0x0A
#define SUBTYPE_AUTH         0x0B
#define SUBTYPE_DEAUTH       0x0C

typedef struct {
    uint16_t frame_ctrl;
    uint16_t duration;
    uint8_t  addr1[6];
    uint8_t  addr2[6];
    uint8_t  addr3[6];
    uint16_t seq_ctrl;
} __attribute__((packed)) ieee80211_mgmt_hdr_t;

// ═══════════════════════════════════════════════════════════════════════════════
// NETWORK TABLE
// ═══════════════════════════════════════════════════════════════════════════════
struct NetworkEntry {
    char     ssid[MAX_SSID_LEN + 1];
    uint8_t  bssid[6];
    int8_t   rssi;
    uint8_t  channel;
    uint32_t lastSeenSec;
    uint16_t frameCount;      // mgmt frames from this BSSID this second
    bool     valid;
};

static NetworkEntry s_networks[MAX_NETWORKS];
static int          s_networkCount = 0;
static portMUX_TYPE s_netMux       = portMUX_INITIALIZER_UNLOCKED;

// ═══════════════════════════════════════════════════════════════════════════════
// PACKET COUNTERS  (volatile — written from WiFi task / ISR)
// ═══════════════════════════════════════════════════════════════════════════════
static volatile uint32_t s_pktCount         = 0;
static volatile uint32_t s_deauthCount      = 0;
static volatile uint32_t s_disassocCount    = 0;
static volatile uint32_t s_probeReqCount    = 0;
static volatile uint32_t s_channelPkts[13]  = {0};
static portMUX_TYPE      s_cntMux           = portMUX_INITIALIZER_UNLOCKED;

// ── Deauth BSSID ring buffer (ISR-safe: only writes, read in main loop) ──
static volatile uint8_t  s_deauthBuf[DEAUTH_BUF_SIZE][6];
static volatile uint32_t s_deauthBufIdx = 0;

// ═══════════════════════════════════════════════════════════════════════════════
// OUI VENDOR LOOKUP TABLE
// ═══════════════════════════════════════════════════════════════════════════════
struct OuiEntry { uint8_t prefix[3]; const char* vendor; };

static const OuiEntry OUI_TABLE[] PROGMEM = {
        {{0x24, 0x6F, 0x28}, "Espressif"}, {{0x30, 0xAE, 0xA4}, "Espressif"},
        {{0xA4, 0xCF, 0x12}, "Espressif"}, {{0x84, 0xF3, 0xEB}, "Espressif"},
        {{0xEC, 0xFA, 0xBC}, "Espressif"}, {{0x48, 0x3F, 0xDA}, "Espressif"},
        {{0x10, 0x52, 0x1C}, "Espressif"}, {{0x7C, 0x87, 0xCE}, "Espressif"},
        {{0xE8, 0x9F, 0x6D}, "Espressif"}, {{0xCC, 0x50, 0xE3}, "Espressif"},
        {{0x50, 0xC7, 0xBF}, "TP-Link"},    {{0x14, 0xEB, 0xB6}, "TP-Link"},
        {{0x54, 0xAF, 0x97}, "TP-Link"},    {{0x98, 0xDA, 0xC4}, "TP-Link"},
        {{0xB0, 0x95, 0x8E}, "TP-Link"},    {{0x30, 0xDE, 0x4B}, "TP-Link"},
        {{0x78, 0x11, 0xDC}, "TP-Link"},
        {{0x00, 0x1A, 0x2B}, "Cisco"},      {{0x00, 0x23, 0xAB}, "Cisco"},
        {{0x78, 0xBA, 0xF9}, "Cisco"},      {{0x00, 0x0C, 0xE7}, "Cisco"},
        {{0x88, 0x75, 0x56}, "Cisco-Meraki"},
        {{0xC0, 0xFF, 0xD4}, "Netgear"},    {{0x28, 0xC6, 0x8E}, "Netgear"},
        {{0x6C, 0xF3, 0x7F}, "Netgear"},
        {{0x2C, 0x4D, 0x54}, "ASUS"},       {{0x10, 0xBF, 0x48}, "ASUS"},
        {{0xAC, 0x84, 0xC6}, "ASUS"},
        {{0x1C, 0xBD, 0xB9}, "D-Link"},     {{0x28, 0x10, 0x7B}, "D-Link"},
        {{0xAC, 0x87, 0xA3}, "Xiaomi"},     {{0x00, 0x9E, 0xC8}, "Xiaomi"},
        {{0x64, 0x09, 0x80}, "Huawei"},     {{0xD8, 0x49, 0x2F}, "Huawei"},
        {{0x00, 0x17, 0xF2}, "Apple"},      {{0x3C, 0x07, 0x54}, "Apple"},
        {{0xA8, 0xBB, 0xCF}, "Apple"},
        {{0x00, 0x27, 0x22}, "Ubiquiti"},   {{0xFC, 0xEC, 0xDA}, "Ubiquiti"},
        {{0x78, 0x8A, 0x20}, "Ubiquiti"},
};
static const int OUI_COUNT = sizeof(OUI_TABLE) / sizeof(OUI_TABLE[0]);

const char* lookupVendor(const uint8_t* mac) {
    for (int i = 0; i < OUI_COUNT; i++) {
        if (mac[0] == OUI_TABLE[i].prefix[0] &&
            mac[1] == OUI_TABLE[i].prefix[1] &&
            mac[2] == OUI_TABLE[i].prefix[2]) {
            return OUI_TABLE[i].vendor;
        }
    }
    return "Unknown";
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════
void macToStr(const uint8_t* mac, char* buf) {
    sprintf(buf, "%02X:%02X:%02X:%02X:%02X:%02X",
            mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
}

bool extractSsid(const uint8_t* payload, int payloadLen,
                 int fixedFieldsLen, char* ssidOut) {
    if (payloadLen <= fixedFieldsLen + 2) return false;
    const uint8_t* ie = payload + fixedFieldsLen;
    int rem = payloadLen - fixedFieldsLen;

    while (rem >= 2) {
        uint8_t tag = ie[0];
        uint8_t len = ie[1];
        if (rem < 2 + (int)len) break;
        if (tag == 0) {
            if (len == 0) {
                strcpy(ssidOut, "<Hidden>");
            } else {
                int n = min((int)len, MAX_SSID_LEN);
                memcpy(ssidOut, ie + 2, n);
                ssidOut[n] = '\0';
                for (int i = 0; i < n; i++) {
                    if ((uint8_t)ssidOut[i] < 0x20 || (uint8_t)ssidOut[i] > 0x7E)
                        ssidOut[i] = '?';
                }
            }
            return true;
        }
        ie  += 2 + len;
        rem -= 2 + len;
    }
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// NETWORK TABLE MANAGEMENT
// ═══════════════════════════════════════════════════════════════════════════════
void upsertNetwork(const char* ssid, const uint8_t* bssid,
                   int8_t rssi, uint8_t channel) {
    uint32_t nowSec = millis() / 1000;
    portENTER_CRITICAL(&s_netMux);

    for (int i = 0; i < s_networkCount; i++) {
        if (memcmp(s_networks[i].bssid, bssid, 6) == 0) {
            s_networks[i].rssi        = rssi;
            s_networks[i].channel     = channel;
            s_networks[i].lastSeenSec = nowSec;
            s_networks[i].frameCount++;
            portEXIT_CRITICAL(&s_netMux);
            return;
        }
    }

    if (s_networkCount >= MAX_NETWORKS) {
        int oldest = 0;
        for (int i = 1; i < s_networkCount; i++) {
            if (s_networks[i].lastSeenSec < s_networks[oldest].lastSeenSec)
                oldest = i;
        }
        strncpy(s_networks[oldest].ssid, ssid, MAX_SSID_LEN);
        s_networks[oldest].ssid[MAX_SSID_LEN] = '\0';
        memcpy(s_networks[oldest].bssid, bssid, 6);
        s_networks[oldest].rssi        = rssi;
        s_networks[oldest].channel     = channel;
        s_networks[oldest].lastSeenSec = nowSec;
        s_networks[oldest].frameCount  = 1;
        s_networks[oldest].valid       = true;
    } else {
        strncpy(s_networks[s_networkCount].ssid, ssid, MAX_SSID_LEN);
        s_networks[s_networkCount].ssid[MAX_SSID_LEN] = '\0';
        memcpy(s_networks[s_networkCount].bssid, bssid, 6);
        s_networks[s_networkCount].rssi        = rssi;
        s_networks[s_networkCount].channel     = channel;
        s_networks[s_networkCount].lastSeenSec = nowSec;
        s_networks[s_networkCount].frameCount  = 1;
        s_networks[s_networkCount].valid       = true;
        s_networkCount++;
    }

    portEXIT_CRITICAL(&s_netMux);
}

void expireOldNetworks() {
    uint32_t nowSec = millis() / 1000;
    portENTER_CRITICAL(&s_netMux);
    for (int i = 0; i < s_networkCount; ) {
        if (nowSec - s_networks[i].lastSeenSec > NETWORK_EXPIRE_SEC) {
            s_networks[i] = s_networks[s_networkCount - 1];
            s_networkCount--;
        } else {
            i++;
        }
    }
    portEXIT_CRITICAL(&s_netMux);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROMISCUOUS SNIFFER CALLBACK
// ═══════════════════════════════════════════════════════════════════════════════
void IRAM_ATTR snifferCb(void* buf, wifi_promiscuous_pkt_type_t type) {
    if (type != WIFI_PKT_MGMT) return;

    const wifi_promiscuous_pkt_t* pkt =
            reinterpret_cast<const wifi_promiscuous_pkt_t*>(buf);
    const int pktLen = pkt->rx_ctrl.sig_len;

    if (pktLen < (int)sizeof(ieee80211_mgmt_hdr_t)) return;

    const ieee80211_mgmt_hdr_t* hdr =
            reinterpret_cast<const ieee80211_mgmt_hdr_t*>(pkt->payload);

    uint8_t ftype    = FC_TYPE(hdr->frame_ctrl);
    uint8_t fsubtype = FC_SUBTYPE(hdr->frame_ctrl);

    if (ftype != FRAME_TYPE_MGMT) return;

    // ── Global per-second counters ──────────────────────────────────
    portENTER_CRITICAL_ISR(&s_cntMux);
    s_pktCount++;
    int ch = (int)pkt->rx_ctrl.channel - 1;
    if (ch >= 0 && ch < 13) s_channelPkts[ch]++;
    portEXIT_CRITICAL_ISR(&s_cntMux);

    // ── Attack detection + deauth BSSID tracking ────────────────────
    if (fsubtype == SUBTYPE_DEAUTH) {
        portENTER_CRITICAL_ISR(&s_cntMux);
        s_deauthCount++;
        // Record deauth BSSID (addr3) into ring buffer
        uint32_t idx = s_deauthBufIdx;
        memcpy((void*)s_deauthBuf[idx], hdr->addr3, 6);
        s_deauthBufIdx = (idx + 1) % DEAUTH_BUF_SIZE;
        portEXIT_CRITICAL_ISR(&s_cntMux);
        return;
    }
    if (fsubtype == SUBTYPE_DISASSOC) {
        portENTER_CRITICAL_ISR(&s_cntMux);
        s_disassocCount++;
        portEXIT_CRITICAL_ISR(&s_cntMux);
        return;
    }
    if (fsubtype == SUBTYPE_PROBE_REQ) {
        portENTER_CRITICAL_ISR(&s_cntMux);
        s_probeReqCount++;
        portEXIT_CRITICAL_ISR(&s_cntMux);
        return;
    }

    // ── Network discovery (Beacon / Probe Response) ─────────────────
    if (fsubtype == SUBTYPE_BEACON || fsubtype == SUBTYPE_PROBE_RESP) {
        const uint8_t* payload = pkt->payload + sizeof(ieee80211_mgmt_hdr_t);
        int            payLen  = pktLen - (int)sizeof(ieee80211_mgmt_hdr_t);
        static const int FIXED = 12;

        char ssid[MAX_SSID_LEN + 1] = {0};
        if (extractSsid(payload, payLen, FIXED, ssid)) {
            upsertNetwork(ssid, hdr->addr3,
                          pkt->rx_ctrl.rssi, pkt->rx_ctrl.channel);
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// JSON SERIALIZATION
// ═══════════════════════════════════════════════════════════════════════════════
void sendJson() {
    // ── Snapshot counters atomically ────────────────────────────────
    portENTER_CRITICAL(&s_cntMux);
    uint32_t snapPkts      = s_pktCount;
    uint32_t snapDeauths   = s_deauthCount;
    uint32_t snapDisassoc  = s_disassocCount;
    uint32_t snapProbe     = s_probeReqCount;
    uint32_t snapCh[13];
    memcpy(snapCh, (const void*)s_channelPkts, sizeof(snapCh));

    // Snapshot deauth BSSID ring buffer
    uint8_t snapDeauthBuf[DEAUTH_BUF_SIZE][6];
    uint32_t snapDeauthIdx = s_deauthBufIdx;
    memcpy(snapDeauthBuf, (const void*)s_deauthBuf, sizeof(snapDeauthBuf));

    // Reset per-second counters
    s_pktCount = s_deauthCount = s_disassocCount = s_probeReqCount = 0;
    memset((void*)s_channelPkts, 0, sizeof(s_channelPkts));
    portEXIT_CRITICAL(&s_cntMux);

    // ── Snapshot network table ──────────────────────────────────────
    portENTER_CRITICAL(&s_netMux);
    int snapCount = s_networkCount;
    NetworkEntry snapNets[MAX_NETWORKS];
    memcpy(snapNets, s_networks, sizeof(NetworkEntry) * snapCount);
    // Reset per-second frame counters
    for (int i = 0; i < s_networkCount; i++) {
        s_networks[i].frameCount = 0;
    }
    portEXIT_CRITICAL(&s_netMux);

    // ── Count unique deauth-targeted BSSIDs ─────────────────────────
    // Deduplicate from the ring buffer
    uint8_t  targetBssids[10][6];   // max 10 unique targets
    uint32_t targetCounts[10] = {0};
    int      targetNum = 0;

    for (uint32_t i = 0; i < DEAUTH_BUF_SIZE; i++) {
        // Walk backwards from the last write
        uint32_t idx = (snapDeauthIdx + DEAUTH_BUF_SIZE - 1 - i) % DEAUTH_BUF_SIZE;
        uint8_t* b = (uint8_t*)snapDeauthBuf[idx];

        // Skip zero entries
        bool zero = true;
        for (int j = 0; j < 6; j++) { if (b[j] != 0) { zero = false; break; } }
        if (zero) continue;

        // Look up in existing targets
        int found = -1;
        for (int t = 0; t < targetNum; t++) {
            if (memcmp(targetBssids[t], b, 6) == 0) { found = t; break; }
        }
        if (found >= 0) {
            targetCounts[found]++;
        } else if (targetNum < 10) {
            memcpy(targetBssids[targetNum], b, 6);
            targetCounts[targetNum] = 1;
            targetNum++;
        }
    }

    // ── Build JSON ──────────────────────────────────────────────────
    StaticJsonDocument<4096> doc;

    doc["timestamp"]       = millis() / 1000;
    doc["packets_per_sec"] = snapPkts;
    doc["deauths"]         = snapDeauths;
    doc["disassocs"]       = snapDisassoc;
    doc["probe_reqs"]      = snapProbe;

    JsonArray congestion = doc.createNestedArray("channel_congestion");
    for (int i = 0; i < 13; i++) congestion.add(snapCh[i]);

    // Deauth targets array
    JsonArray targets = doc.createNestedArray("deauth_targets");
    for (int t = 0; t < targetNum; t++) {
        char bStr[18];
        macToStr(targetBssids[t], bStr);
        targets.add(bStr);
    }

    // Networks with per-AP frame counts
    JsonArray netsArr = doc.createNestedArray("networks");
    for (int i = 0; i < snapCount; i++) {
        JsonObject n = netsArr.createNestedObject();
        char bssidStr[18];
        macToStr(snapNets[i].bssid, bssidStr);
        n["ssid"]       = snapNets[i].ssid;
        n["bssid"]      = bssidStr;
        n["rssi"]       = snapNets[i].rssi;
        n["channel"]    = snapNets[i].channel;
        n["oui_vendor"] = lookupVendor(snapNets[i].bssid);
        n["frames"]     = snapNets[i].frameCount;
    }

    serializeJson(doc, Serial);
    Serial.println();
}

// ═══════════════════════════════════════════════════════════════════════════════
// SETUP
// ═══════════════════════════════════════════════════════════════════════════════
uint8_t g_currentChannel = 1;
uint32_t g_lastHopMs     = 0;
uint32_t g_lastJsonMs    = 0;

void setup() {
    Serial.begin(SERIAL_BAUD);
    delay(500);

    Serial.println(">> SAFE-NET AUDITOR v1.1 BOOTING...");
    Serial.println(">> CORE 0: WiFi Task | CORE 1: Arduino Loop");

    WiFi.mode(WIFI_STA);
    WiFi.disconnect();
    delay(100);

    esp_wifi_set_promiscuous(true);

    wifi_promiscuous_filter_t filt = {
            .filter_mask = WIFI_PROMIS_FILTER_MASK_MGMT
    };
    esp_wifi_set_promiscuous_filter(&filt);
    esp_wifi_set_promiscuous_rx_cb(&snifferCb);

    esp_wifi_set_channel(g_currentChannel, WIFI_SECOND_CHAN_NONE);

    g_lastHopMs  = millis();
    g_lastJsonMs = millis();

    Serial.println(">> PROMISCUOUS MODE: ACTIVE");
    Serial.println(">> CHANNEL HOP: 1-13 @ 60ms intervals");
    Serial.println(">> JSON OUTPUT: 1Hz");
    Serial.println(">> DEAUTH TARGET TRACKING: ENABLED");
    Serial.println(">> SNIFFING...");
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN LOOP
// ═══════════════════════════════════════════════════════════════════════════════
void loop() {
    uint32_t now = millis();

    if (now - g_lastHopMs >= CHANNEL_HOP_MS) {
        g_currentChannel = (g_currentChannel % 13) + 1;
        esp_wifi_set_channel(g_currentChannel, WIFI_SECOND_CHAN_NONE);
        g_lastHopMs = now;
    }

    if (now - g_lastJsonMs >= JSON_INTERVAL_MS) {
        expireOldNetworks();
        sendJson();
        g_lastJsonMs = now;
    }

    delay(1);
}
