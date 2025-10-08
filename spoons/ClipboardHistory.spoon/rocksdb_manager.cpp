#include <iostream>
#include <string>
#include <vector>
#include <ctime>
#include <cstdlib>
#include <sstream>
#include <iomanip>
#include <algorithm>
#include <cctype>
#include <rocksdb/db.h>
#include <rocksdb/options.h>
#include <rocksdb/slice.h>
#include <rocksdb/iterator.h>
#include <json/json.h>

class ClipboardDB {
private:
    rocksdb::DB* db;
    rocksdb::Options options;
    std::string db_path;

public:
    ClipboardDB(const std::string& path) : db_path(path) {
        options.create_if_missing = true;
        options.compression = rocksdb::kSnappyCompression;
        options.write_buffer_size = 4 * 1024 * 1024; // 4MB
        options.max_write_buffer_number = 2;
        options.target_file_size_base = 16 * 1024 * 1024; // 16MB
        
        rocksdb::Status status = rocksdb::DB::Open(options, db_path, &db);
        if (!status.ok()) {
            std::cerr << "ERROR: Cannot open RocksDB: " << status.ToString() << std::endl;
            exit(1);
        }
    }

    ~ClipboardDB() {
        delete db;
    }

    std::string getCurrentTimestamp() {
        auto now = std::time(nullptr);
        std::ostringstream oss;
        oss << std::put_time(std::localtime(&now), "%H:%M");
        return oss.str();
    }

    uint64_t getCurrentUnixTimestamp() {
        return static_cast<uint64_t>(std::time(nullptr));
    }

    std::string addEntry(const std::string& content, const std::string& type, 
                        const std::string& preview, const std::string& size) {
        uint64_t timestamp = getCurrentUnixTimestamp();
        std::string time_str = getCurrentTimestamp();
        
        // Generate unique ID
        std::string id = std::to_string(timestamp) + "_" + std::to_string(rand() % 10000);
        
        // Check for duplicates in recent entries
        std::string existing_id = findDuplicate(content);
        if (!existing_id.empty()) {
            // Update existing entry timestamp
            updateTimestamp(existing_id, timestamp, time_str);
            return buildEntryJson(existing_id, content, type, preview, size, timestamp, time_str, "moved");
        }

        // Create entry metadata
        Json::Value entry;
        entry["id"] = id;
        entry["content"] = content;
        entry["type"] = type;
        entry["preview"] = preview;
        entry["size"] = size;
        entry["timestamp"] = static_cast<Json::Int64>(timestamp);
        entry["time"] = time_str;

        Json::StreamWriterBuilder builder;
        std::string json_str = Json::writeString(builder, entry);

        // Store in RocksDB
        std::string entry_key = "entry:" + std::to_string(timestamp) + ":" + id;
        std::string content_key = "content:" + id;
        std::string recent_key = "recent:" + std::to_string(timestamp) + ":" + id;

        rocksdb::WriteBatch batch;
        batch.Put(entry_key, json_str);
        batch.Put(content_key, content);
        batch.Put(recent_key, id);

        rocksdb::WriteOptions write_options;
        rocksdb::Status status = db->Write(write_options, &batch);
        
        if (!status.ok()) {
            std::cerr << "ERROR: Write failed: " << status.ToString() << std::endl;
            return "{}";
        }

        // Cleanup old entries (keep last 300)
        cleanupOldEntries(300);

        return buildEntryJson(id, content, type, preview, size, timestamp, time_str, "added");
    }

    std::string findDuplicate(const std::string& content) {
        // Scan recent entries for duplicates
        rocksdb::ReadOptions read_options;
        std::unique_ptr<rocksdb::Iterator> it(db->NewIterator(read_options));

        int checked = 0;
        for (it->SeekToLast(); it->Valid() && checked < 50; it->Prev()) {
            std::string key = it->key().ToString();
            if (key.substr(0, 6) == "entry:") {
                Json::Value entry;
                Json::CharReaderBuilder builder;
                std::string errors;
                std::istringstream json_stream(it->value().ToString());

                if (Json::parseFromStream(builder, json_stream, &entry, &errors)) {
                    if (entry["content"].asString() == content) {
                        return entry["id"].asString();
                    }
                }
                checked++;
            }
        }
        return "";
    }

    void updateTimestamp(const std::string& id, uint64_t timestamp, const std::string& time_str) {
        // Find and update existing entry
        rocksdb::ReadOptions read_options;
        std::unique_ptr<rocksdb::Iterator> it(db->NewIterator(read_options));
        
        for (it->SeekToFirst(); it->Valid(); it->Next()) {
            std::string key = it->key().ToString();
            if (key.substr(0, 6) == "entry:") {
                Json::Value entry;
                Json::CharReaderBuilder builder;
                std::string errors;
                std::istringstream json_stream(it->value().ToString());
                
                if (Json::parseFromStream(builder, json_stream, &entry, &errors)) {
                    if (entry["id"].asString() == id) {
                        // Delete old keys
                        rocksdb::WriteBatch batch;
                        batch.Delete(key);
                        
                        // Update entry
                        entry["timestamp"] = static_cast<Json::Int64>(timestamp);
                        entry["time"] = time_str;
                        
                        Json::StreamWriterBuilder write_builder;
                        std::string updated_json = Json::writeString(write_builder, entry);
                        
                        // Add new keys
                        std::string new_entry_key = "entry:" + std::to_string(timestamp) + ":" + id;
                        std::string new_recent_key = "recent:" + std::to_string(timestamp) + ":" + id;
                        
                        batch.Put(new_entry_key, updated_json);
                        batch.Put(new_recent_key, id);
                        
                        rocksdb::WriteOptions write_options;
                        db->Write(write_options, &batch);
                        break;
                    }
                }
            }
        }
    }

    std::string getRecentEntries(int limit) {
        Json::Value results(Json::arrayValue);
        rocksdb::ReadOptions read_options;
        std::unique_ptr<rocksdb::Iterator> it(db->NewIterator(read_options));
        
        int count = 0;
        for (it->SeekToLast(); it->Valid() && count < limit; it->Prev()) {
            std::string key = it->key().ToString();
            if (key.substr(0, 6) == "entry:") {
                Json::Value entry;
                Json::CharReaderBuilder builder;
                std::string errors;
                std::istringstream json_stream(it->value().ToString());
                
                if (Json::parseFromStream(builder, json_stream, &entry, &errors)) {
                    results.append(entry);
                    count++;
                }
            }
        }

        Json::StreamWriterBuilder builder;
        return Json::writeString(builder, results);
    }

    std::string searchEntries(const std::string& query, int limit) {
        Json::Value results(Json::arrayValue);
        rocksdb::ReadOptions read_options;
        std::unique_ptr<rocksdb::Iterator> it(db->NewIterator(read_options));
        auto toLower = [](const std::string& value) {
            std::string lower = value;
            std::transform(lower.begin(), lower.end(), lower.begin(),
                [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
            return lower;
        };
        std::string queryLower = toLower(query);
        
        int count = 0;
        for (it->SeekToFirst(); it->Valid() && count < limit; it->Next()) {
            std::string key = it->key().ToString();
            if (key.substr(0, 8) == "content:") {
                std::string content = it->value().ToString();
                std::string contentLower = toLower(content);
                if (contentLower.find(queryLower) != std::string::npos) {
                    // Get corresponding entry
                    std::string id = key.substr(8); // Remove "content:" prefix
                    std::string entry = getEntryById(id);
                    if (!entry.empty()) {
                        Json::Value entry_obj;
                        Json::CharReaderBuilder builder;
                        std::string errors;
                        std::istringstream json_stream(entry);
                        
                        if (Json::parseFromStream(builder, json_stream, &entry_obj, &errors)) {
                            results.append(entry_obj);
                            count++;
                        }
                    }
                }
            }
        }

        Json::StreamWriterBuilder builder;
        return Json::writeString(builder, results);
    }

    std::string getEntryById(const std::string& id) {
        rocksdb::ReadOptions read_options;
        std::unique_ptr<rocksdb::Iterator> it(db->NewIterator(read_options));
        
        for (it->SeekToFirst(); it->Valid(); it->Next()) {
            std::string key = it->key().ToString();
            if (key.substr(0, 6) == "entry:" && key.find(":" + id) != std::string::npos) {
                return it->value().ToString();
            }
        }
        return "";
    }

    std::string getCount() {
        int count = 0;
        rocksdb::ReadOptions read_options;
        std::unique_ptr<rocksdb::Iterator> it(db->NewIterator(read_options));
        
        for (it->SeekToFirst(); it->Valid(); it->Next()) {
            std::string key = it->key().ToString();
            if (key.substr(0, 6) == "entry:") {
                count++;
            }
        }

        Json::Value result;
        result["count"] = count;
        Json::StreamWriterBuilder builder;
        return Json::writeString(builder, result);
    }

    void cleanupOldEntries(int max_entries) {
        std::vector<std::pair<uint64_t, std::string>> entries;
        rocksdb::ReadOptions read_options;
        std::unique_ptr<rocksdb::Iterator> it(db->NewIterator(read_options));
        
        // Collect all entries with timestamps
        for (it->SeekToFirst(); it->Valid(); it->Next()) {
            std::string key = it->key().ToString();
            if (key.substr(0, 6) == "entry:") {
                size_t first_colon = key.find(':', 6);
                size_t second_colon = key.find(':', first_colon + 1);
                if (first_colon != std::string::npos && second_colon != std::string::npos) {
                    uint64_t timestamp = std::stoull(key.substr(6, first_colon - 6));
                    std::string id = key.substr(second_colon + 1);
                    entries.push_back({timestamp, id});
                }
            }
        }
        
        if (entries.size() > max_entries) {
            // Sort by timestamp (oldest first)
            std::sort(entries.begin(), entries.end());
            
            // Delete oldest entries
            rocksdb::WriteBatch batch;
            for (size_t i = 0; i < entries.size() - max_entries; i++) {
                std::string id = entries[i].second;
                uint64_t timestamp = entries[i].first;
                
                batch.Delete("entry:" + std::to_string(timestamp) + ":" + id);
                batch.Delete("content:" + id);
                batch.Delete("recent:" + std::to_string(timestamp) + ":" + id);
            }
            
            rocksdb::WriteOptions write_options;
            db->Write(write_options, &batch);
        }
    }

    std::string buildEntryJson(const std::string& id, const std::string& content,
                              const std::string& type, const std::string& preview,
                              const std::string& size, uint64_t timestamp,
                              const std::string& time_str, const std::string& action) {
        Json::Value entry;
        entry["id"] = id;
        entry["content"] = content;
        entry["type"] = type;
        entry["preview"] = preview;
        entry["size"] = size;
        entry["timestamp"] = static_cast<Json::Int64>(timestamp);
        entry["time"] = time_str;
        entry["action"] = action;

        Json::StreamWriterBuilder builder;
        return Json::writeString(builder, entry);
    }

    void clear() {
        rocksdb::ReadOptions read_options;
        rocksdb::WriteBatch batch;
        std::unique_ptr<rocksdb::Iterator> it(db->NewIterator(read_options));
        
        for (it->SeekToFirst(); it->Valid(); it->Next()) {
            batch.Delete(it->key());
        }
        
        rocksdb::WriteOptions write_options;
        db->Write(write_options, &batch);
    }
};

int main(int argc, char* argv[]) {
    if (argc < 3) {
        std::cout << "Usage: " << argv[0] << " <db_path> <command> [args...]" << std::endl;
        std::cout << "Commands:" << std::endl;
        std::cout << "  add <content> <type> <preview> <size>" << std::endl;
        std::cout << "  recent <limit>" << std::endl;
        std::cout << "  search <query> <limit>" << std::endl;
        std::cout << "  count" << std::endl;
        std::cout << "  clear" << std::endl;
        return 1;
    }

    std::string db_path = argv[1];
    std::string command = argv[2];

    try {
        ClipboardDB db(db_path);

        if (command == "add" && argc >= 7) {
            std::string content = argv[3];
            std::string type = argv[4];
            std::string preview = argv[5];
            std::string size = argv[6];
            std::cout << db.addEntry(content, type, preview, size) << std::endl;
        }
        else if (command == "recent") {
            int limit = (argc > 3) ? std::atoi(argv[3]) : 25;
            std::cout << db.getRecentEntries(limit) << std::endl;
        }
        else if (command == "search" && argc >= 4) {
            std::string query = argv[3];
            int limit = (argc > 4) ? std::atoi(argv[4]) : 100;
            std::cout << db.searchEntries(query, limit) << std::endl;
        }
        else if (command == "count") {
            std::cout << db.getCount() << std::endl;
        }
        else if (command == "clear") {
            db.clear();
            std::cout << "{\"status\":\"cleared\"}" << std::endl;
        }
        else {
            std::cerr << "ERROR: Invalid command or insufficient arguments" << std::endl;
            return 1;
        }
    } catch (const std::exception& e) {
        std::cerr << "ERROR: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}
