//
//  StringHelpers.swift
//  informed
//
//  Utility functions for string manipulation
//

import Foundation

// MARK: - Domain Extraction

func extractDomainName(from urlString: String) -> String {
    guard let url = URL(string: urlString),
          let host = url.host else {
        return urlString
    }

    // Remove www. prefix if present
    var domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host

    // Take only the main domain (e.g., "nytimes.com" from "www.nytimes.com")
    let components = domain.split(separator: ".")
    if components.count > 1 {
        domain = components.dropFirst(max(0, components.count - 2)).joined(separator: ".")
    }

    return domain.capitalized
}

// MARK: - Date Formatting

func formatDate(_ dateString: String) -> String {
    // Format: "20251106" -> "Nov 6, 2025"
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd"
    
    if let date = formatter.date(from: dateString) {
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    return dateString
}
