import SwiftUI
import CoreLocation
import Combine

struct LocationTestView: View {
    @StateObject private var viewModel = LocationViewModel()
    
    var body: some View {
        VStack(spacing: 12) {
            Text("📍 Location Tester")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            if let location = viewModel.currentLocation {
                Text("Latitude: \(String(format: "%.6f", location.latitude))")
                Text("Longitude: \(String(format: "%.6f", location.longitude))")
            } else {
                Text("Fetching location...")
            }
            
            if viewModel.fullAddress != "-" {
                Text("📍 \(viewModel.fullAddress)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Divider().padding(.vertical, 8)
            
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    Text("Landmark: \(viewModel.landmark)")
                    Text("Sublocality: \(viewModel.sublocality)")
                    Text("Locality: \(viewModel.locality)")
                    Text("District: \(viewModel.district)")
                    Text("State: \(viewModel.state)")
                    Text("Country: \(viewModel.country)")
                    Text("Pincode: \(viewModel.pincode)")
                }
                .font(.system(size: 16))
            }
            .padding(.horizontal)
            
            // Custom Full Address Section
            if viewModel.customFullAddress != "-" {
                Divider().padding(.vertical, 8)
                
                Text("🗺️ Custom Full Address")
                    .font(.headline)
                    .padding(.top, 8)
                
                Text(viewModel.customFullAddress)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Example button to test custom address lookup
            Button("Get Custom Address") {
                // Example: Get address for a custom coordinate
                viewModel.getAddressFromCoordinates(latitude: 26.9289222, longitude: 75.6931912) { addressData in
                    print("Received address data:", addressData)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .padding()
        .onAppear {
            viewModel.requestLocation()
        }
    }
}

final class LocationViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let apiKey = "AIzaSyAykCJf7IEOKPUp90tf911Su6J092R6Kkg" // 🔑 Your Google Maps API Key
    
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var fullAddress = "-"
    @Published var landmark = "-"
    @Published var sublocality = "-"
    @Published var locality = "-"
    @Published var district = "-"
    @Published var state = "-"
    @Published var country = "-"
    @Published var pincode = "-"
    
    // Custom address
    @Published var customFullAddress = "-"
    @Published var customAddressData: [String: Any] = [:]
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        currentLocation = location.coordinate
        fetchAddress(for: location.coordinate)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error.localizedDescription)
    }
    
    // MARK: - Fetch address using Google Geocoding API
    private func fetchAddress(for coordinate: CLLocationCoordinate2D) {
        let urlString = "https://maps.googleapis.com/maps/api/geocode/json?latlng=\(coordinate.latitude),\(coordinate.longitude)&key=\(apiKey)"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            // Check for network errors
            if let error = error {
                print("❌ Network error:", error.localizedDescription)
                return
            }
            
            guard let data = data else {
                print("❌ No data received")
                return
            }
            
            // Print raw response for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📡 API Response:", jsonString)
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                
                // ✅ CHECK STATUS FIRST
                if let status = json?["status"] as? String {
                    print("📍 API Status:", status)
                    
                    if status != "OK" {
                        if let errorMessage = json?["error_message"] as? String {
                            print("❌ API Error:", errorMessage)
                        }
                        return
                    }
                }
                
                guard let results = json?["results"] as? [[String: Any]],
                      let first = results.first,
                      let components = first["address_components"] as? [[String: Any]] else {
                    print("❌ Invalid JSON structure")
                    return
                }
                
                // Extract full formatted address
                let formattedAddress = first["formatted_address"] as? String ?? "-"
                
                DispatchQueue.main.async {
                    self.fullAddress = formattedAddress
                    self.parseAddressComponents(components)
                }
            } catch {
                print("❌ Parsing error:", error.localizedDescription)
            }
        }.resume()
    }
    
    // MARK: - Get Address from Custom Coordinates
    /// Fetches the address for given latitude and longitude coordinates
    /// - Parameters:
    ///   - latitude: The latitude coordinate
    ///   - longitude: The longitude coordinate
    ///   - completion: Completion handler that returns a dictionary with address data
    func getAddressFromCoordinates(latitude: Double, longitude: Double, completion: @escaping ([String: Any]) -> Void) {
        let urlString = "https://maps.googleapis.com/maps/api/geocode/json?latlng=\(latitude),\(longitude)&key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            completion(["error": "Invalid URL"])
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            // Check for network errors
            if let error = error {
                print("❌ Network error:", error.localizedDescription)
                completion(["error": error.localizedDescription])
                return
            }
            
            guard let data = data else {
                print("❌ No data received")
                completion(["error": "No data received"])
                return
            }
            
            // Print raw response for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📡 Custom API Response:", jsonString)
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                
                // Check status
                if let status = json?["status"] as? String {
                    print("📍 Custom API Status:", status)
                    
                    if status != "OK" {
                        if let errorMessage = json?["error_message"] as? String {
                            print("❌ API Error:", errorMessage)
                            completion(["error": errorMessage])
                        } else {
                            completion(["error": "API returned status: \(status)"])
                        }
                        return
                    }
                }
                
                guard let results = json?["results"] as? [[String: Any]],
                      let first = results.first else {
                    print("❌ Invalid JSON structure")
                    completion(["error": "Invalid JSON structure"])
                    return
                }
                
                // Extract full formatted address
                let formattedAddress = first["formatted_address"] as? String ?? "-"
                let addressComponents = first["address_components"] as? [[String: Any]] ?? []
                
                // Parse address components
                var addressData: [String: Any] = [
                    "formatted_address": formattedAddress,
                    "latitude": latitude,
                    "longitude": longitude
                ]
                
                var landmark = "-"
                var sublocality = "-"
                var locality = "-"
                var district = "-"
                var state = "-"
                var country = "-"
                var pincode = "-"
                
                for comp in addressComponents {
                    guard let types = comp["types"] as? [String],
                          let longName = comp["long_name"] as? String else { continue }
                    
                    if types.contains("point_of_interest") || types.contains("establishment") {
                        landmark = longName
                    } else if types.contains("sublocality") || types.contains("sublocality_level_1") {
                        sublocality = longName
                    } else if types.contains("locality") {
                        locality = longName
                    } else if types.contains("administrative_area_level_2") {
                        district = longName
                    } else if types.contains("administrative_area_level_1") {
                        state = longName
                    } else if types.contains("country") {
                        country = longName
                    } else if types.contains("postal_code") {
                        pincode = longName
                    }
                }
                
                addressData["landmark"] = landmark
                addressData["sublocality"] = sublocality
                addressData["locality"] = locality
                addressData["district"] = district
                addressData["state"] = state
                addressData["country"] = country
                addressData["pincode"] = pincode
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.customFullAddress = formattedAddress
                    self.customAddressData = addressData
                }
                
                // Return the complete address data
                completion(addressData)
                
            } catch {
                print("❌ Parsing error:", error.localizedDescription)
                completion(["error": "Parsing error: \(error.localizedDescription)"])
            }
        }.resume()
    }
    
    // MARK: - Extract specific fields from JSON
    private func parseAddressComponents(_ components: [[String: Any]]) {
        for comp in components {
            guard let types = comp["types"] as? [String],
                  let longName = comp["long_name"] as? String else { continue }
            
            if types.contains("point_of_interest") || types.contains("establishment") {
                landmark = longName
            } else if types.contains("sublocality") || types.contains("sublocality_level_1") {
                sublocality = longName
            } else if types.contains("locality") {
                locality = longName
            } else if types.contains("administrative_area_level_2") {
                district = longName
            } else if types.contains("administrative_area_level_1") {
                state = longName
            } else if types.contains("country") {
                country = longName
            } else if types.contains("postal_code") {
                pincode = longName
            }
        }
    }
}
