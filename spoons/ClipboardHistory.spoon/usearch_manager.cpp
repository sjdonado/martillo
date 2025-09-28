#include <iostream>
#include <string>
#include <vector>
#include <sstream>
#include <json/json.h>
#include <rocksdb/db.h>

// USearch manager that uses RocksDB for storing vector-to-entry mappings
// This integrates with the main ClipboardHistory RocksDB instance
class EmbeddingManager {
private:
    std::string db_path;
    rocksdb::DB* db;
    int next_vector_id;

public:
    EmbeddingManager(const std::string& path) : db_path(path), db(nullptr), next_vector_id(0) {
        openDatabase();
        loadNextVectorId();
    }
    
    ~EmbeddingManager() {
        if (db) {
            delete db;
        }
    }

    void openDatabase() {
        rocksdb::Options options;
        options.create_if_missing = true;
        
        rocksdb::Status status = rocksdb::DB::Open(options, db_path, &db);
        if (!status.ok()) {
            std::cerr << "Failed to open RocksDB: " << status.ToString() << std::endl;
            db = nullptr;
        }
    }
    
    void loadNextVectorId() {
        if (!db) return;
        
        // Get the next vector ID from a special key
        std::string value;
        rocksdb::Status status = db->Get(rocksdb::ReadOptions(), "__usearch_next_id", &value);
        if (status.ok()) {
            next_vector_id = std::stoi(value);
        } else {
            next_vector_id = 0;
        }
    }
    
    void saveNextVectorId() {
        if (!db) return;
        
        rocksdb::Status status = db->Put(rocksdb::WriteOptions(), "__usearch_next_id", std::to_string(next_vector_id));
        if (!status.ok()) {
            std::cerr << "Failed to save next vector ID: " << status.ToString() << std::endl;
        }
    }

    // Simple word-based embedding (bag of words approach)
    std::vector<float> createEmbedding(const std::string& text) {
        std::vector<float> embedding(128, 0.0f); // Fixed size embedding
        
        // Simple hash-based embedding
        std::hash<std::string> hasher;
        std::stringstream ss(text);
        std::string word;
        int word_count = 0;
        
        while (ss >> word && word_count < 32) {
            size_t hash_val = hasher(word);
            for (int i = 0; i < 4; ++i) {
                embedding[(word_count * 4 + i) % 128] += (float)((hash_val >> (i * 8)) & 0xFF) / 255.0f;
            }
            word_count++;
        }
        
        // Normalize
        float norm = 0.0f;
        for (float val : embedding) {
            norm += val * val;
        }
        if (norm > 0) {
            norm = std::sqrt(norm);
            for (float& val : embedding) {
                val /= norm;
            }
        }
        
        return embedding;
    }

    bool addEntry(const std::string& entry_id, const std::string& content) {
        if (!db) return false;
        
        try {
            // Store mapping: vector_id -> entry_id
            std::string vector_key = "__usearch_mapping_" + std::to_string(next_vector_id);
            rocksdb::Status status = db->Put(rocksdb::WriteOptions(), vector_key, entry_id);
            
            if (status.ok()) {
                next_vector_id++;
                saveNextVectorId();
                return true;
            } else {
                std::cerr << "Failed to store mapping: " << status.ToString() << std::endl;
                return false;
            }
        } catch (const std::exception& e) {
            std::cerr << "Error adding entry: " << e.what() << std::endl;
            return false;
        }
    }

    std::vector<std::string> searchSimilar(const std::string& query, int limit) {
        std::vector<std::string> results;
        if (!db) return results;
        
        // Get all mappings from RocksDB by iterating over mapping keys
        std::vector<std::pair<std::string, std::string>> candidates;
        
        rocksdb::Iterator* it = db->NewIterator(rocksdb::ReadOptions());
        for (it->SeekToFirst(); it->Valid(); it->Next()) {
            std::string key = it->key().ToString();
            if (key.substr(0, 18) == "__usearch_mapping_") {
                std::string vector_id = key.substr(18);
                std::string entry_id = it->value().ToString();
                candidates.push_back({vector_id, entry_id});
            }
        }
        delete it;
        
        // Simple similarity based on common words
        std::string query_lower = query;
        std::transform(query_lower.begin(), query_lower.end(), query_lower.begin(), ::tolower);
        
        std::vector<std::pair<int, std::string>> scored_results;
        for (const auto& candidate : candidates) {
            std::string id_lower = candidate.second;
            std::transform(id_lower.begin(), id_lower.end(), id_lower.begin(), ::tolower);
            
            int score = 0;
            std::stringstream ss(query_lower);
            std::string word;
            while (ss >> word) {
                if (id_lower.find(word) != std::string::npos) {
                    score++;
                }
            }
            
            if (score > 0) {
                scored_results.push_back({score, candidate.second});
            }
        }
        
        // Sort by score (descending)
        std::sort(scored_results.begin(), scored_results.end(), 
                  [](const auto& a, const auto& b) { return a.first > b.first; });
        
        // Return top results
        for (int i = 0; i < std::min(limit, (int)scored_results.size()); ++i) {
            results.push_back(scored_results[i].second);
        }
        
        return results;
    }

    void clear() {
        if (!db) return;
        
        // Clear all mapping keys
        rocksdb::Iterator* it = db->NewIterator(rocksdb::ReadOptions());
        for (it->SeekToFirst(); it->Valid(); it->Next()) {
            std::string key = it->key().ToString();
            if (key.substr(0, 18) == "__usearch_mapping_") {
                db->Delete(rocksdb::WriteOptions(), key);
            }
        }
        delete it;
        
        // Reset next vector ID
        next_vector_id = 0;
        saveNextVectorId();
    }
};

int main(int argc, char* argv[]) {
    if (argc < 3) {
        std::cerr << "Usage: " << argv[0] << " <index_path> <command> [args...]" << std::endl;
        return 1;
    }

    std::string index_path = argv[1];
    std::string command = argv[2];
    
    EmbeddingManager manager(index_path);

    if (command == "add" && argc >= 5) {
        std::string entry_id = argv[3];
        std::string content = argv[4];
        
        if (manager.addEntry(entry_id, content)) {
            std::cout << "Added entry: " << entry_id << std::endl;
        } else {
            std::cerr << "Failed to add entry" << std::endl;
            return 1;
        }
        
    } else if (command == "search" && argc >= 5) {
        std::string query = argv[3];
        int limit = std::stoi(argv[4]);
        
        auto results = manager.searchSimilar(query, limit);
        
        Json::Value json_results(Json::arrayValue);
        for (const auto& result : results) {
            Json::Value entry;
            entry["id"] = result;
            json_results.append(entry);
        }
        
        Json::StreamWriterBuilder builder;
        std::unique_ptr<Json::StreamWriter> writer(builder.newStreamWriter());
        writer->write(json_results, &std::cout);
        
    } else if (command == "clear") {
        manager.clear();
        std::cout << "Index cleared" << std::endl;
        
    } else {
        std::cerr << "Unknown command: " << command << std::endl;
        return 1;
    }

    return 0;
}