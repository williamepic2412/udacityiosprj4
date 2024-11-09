//
//  JournalService+Live.swift
//  TripJournal
//
//  Created by William Epic on 09/11/2024.
//

import Combine
import Foundation

class JournalServiceLive: JournalService {
    
    // MARK: - Properties
    private var token: Token?
    private var authenticationSubject = CurrentValueSubject<Bool, Never>(false)
    private var trips: [Trip] = []
    
    /// A publisher that can be observed to indicate whether the user is authenticated or not.
    var isAuthenticated: AnyPublisher<Bool, Never> {
        authenticationSubject.eraseToAnyPublisher()
    }

    private func implementRequest<T>(dataToEncode: T, httpMethod: String, domain: String, path: String?) async throws -> (Data, URLResponse) where T: Encodable {
        
        let encode = try JSONEncoder().encode(dataToEncode)
        let baseURL = "http://localhost:8000/\(domain)\(path.map { "/\($0)" } ?? "")"
        
        guard let api = URL(string: baseURL) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: api)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let tok = token {
            request.setValue("Bearer \(tok.accessToken)", forHTTPHeaderField: "Authorization")
            print("Using token: \(tok.accessToken)")
        } else {
            print("Token is nil")
        }
        
        request.httpMethod = httpMethod
        if httpMethod != "GET" {
            request.httpBody = encode
        }
        
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            print("Network error: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Authentication Methods
    func register(username: String, password: String) async throws -> Token {
        
        let createUser: [String: String] = ["username": username, "password": password]
        let encode = try JSONEncoder().encode(createUser)
        
        guard let api = URL(string: "http://localhost:8000/register") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: api)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = encode
        
        let (data, response) = try await URLSession.shared.data(for: request)
        print("Register response: \(response)")
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Error during registration: \(errorMessage)")
            throw URLError(.userAuthenticationRequired)
        }
        
        do {
            let decodedToken = try JSONDecoder().decode(Token.self, from: data)
            self.token = decodedToken
            DispatchQueue.main.async { self.authenticationSubject.send(true) }
            return decodedToken
        } catch {
            print("Decoding error during registration: \(error.localizedDescription)")
            throw error
        }
    }

    func logOut() {
        token = nil
        DispatchQueue.main.async { self.authenticationSubject.send(false) }
        print("Logged out")
    }

    func logIn(username: String, password: String) async throws -> Token {
        
        let parameters: [String: String] = [
            "grant_type": "",
            "username": username,
            "password": password,
            "scope": "",
            "client_id": "",
            "client_secret": ""
        ]
        
        let encodedParameters = parameters.map { "\($0.key)=\($0.value)" }
                                           .joined(separator: "&")
                                           .data(using: .utf8)
        
        guard let api = URL(string: "http://localhost:8000/token") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: api)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = encodedParameters
        
        let (data, response) = try await URLSession.shared.data(for: request)
        print("Login response: \(response)")
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Error during login: \(errorMessage)")
            throw URLError(.userAuthenticationRequired)
        }
        
        do {
            let decodedToken = try JSONDecoder().decode(Token.self, from: data)
            self.token = decodedToken
            DispatchQueue.main.async { self.authenticationSubject.send(true) }
            return decodedToken
        } catch {
            print("Decoding error during login: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Trip Methods
    func getTrips() async throws -> [Trip] {
        let (data, response) = try await implementRequest(dataToEncode: Data(), httpMethod: "GET", domain: "trips", path: nil)
        print("Getting trips response: \(response)")
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Error getting trips: \(errorMessage)")
            throw URLError(.userAuthenticationRequired)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let decodedTrips = try decoder.decode([Trip].self, from: data)
            trips = decodedTrips
            return trips
        } catch {
            print("Decoding error while fetching trips: \(error.localizedDescription)")
            throw error
        }
    }

    func createTrip(with request: TripCreate) async throws -> Trip {
        
        print("Request to create trip: \(request)")
        
        let dateFormatter = ISO8601DateFormatter()
        let startDateString = dateFormatter.string(from: request.startDate)
        let endDateString = dateFormatter.string(from: request.endDate)
        
        let dataToEncode: [String: String] = [
            "name": request.name,
            "start_date": startDateString,
            "end_date": endDateString
        ]
        
        let (data, response) = try await implementRequest(dataToEncode: dataToEncode, httpMethod: "POST", domain: "trips", path: nil)
        print("Create trip response: \(response)")
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Error creating trip: \(errorMessage)")
            throw URLError(.userAuthenticationRequired)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let decodedTrip = try decoder.decode(Trip.self, from: data)
            trips.append(decodedTrip)
            trips.sort()
            return decodedTrip
        } catch {
            print("Decoding error while creating trip: \(error.localizedDescription)")
            throw error
        }
    }

    func getTrip(withId tripId: Trip.ID) async throws -> Trip {
        let (data, response) = try await implementRequest(dataToEncode: Data(), httpMethod: "GET", domain: "trips", path: "\(tripId)")
        print("Getting trip response: \(response)")
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let decodedTrip = try decoder.decode(Trip.self, from: data)
            return decodedTrip
        } catch {
            print("Decoding error while fetching trip: \(error.localizedDescription)")
            throw error
        }
    }

    func updateTrip(withId tripId: Trip.ID, and request: TripUpdate) async throws -> Trip {
        let dateFormatter = ISO8601DateFormatter()
        let startDateString = dateFormatter.string(from: request.startDate)
        let endDateString = dateFormatter.string(from: request.endDate)
        
        let dataToEncode: [String: String] = [
            "name": request.name,
            "start_date": startDateString,
            "end_date": endDateString
        ]
        
        let (data, response) = try await implementRequest(dataToEncode: dataToEncode, httpMethod: "PUT", domain: "trips", path: "\(tripId)")
        print("Update trip response: \(response)")
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let updatedTrip = try decoder.decode(Trip.self, from: data)
            
            guard let tripIndex = trips.firstIndex(where: { $0.id == tripId }) else {
                throw URLError(.unknown)
            }
            
            trips[tripIndex] = updatedTrip
            trips.sort()
            return updatedTrip
        } catch {
            print("Decoding error while updating trip: \(error.localizedDescription)")
            throw error
        }
    }

    func deleteTrip(withId tripId: Trip.ID) async throws {
        let (_, response) = try await implementRequest(dataToEncode: Data(), httpMethod: "DELETE", domain: "trips", path: "\(tripId)")
        print("Delete trip response: \(response)")
        
        trips.removeAll { $0.id == tripId }
        print("Trip with ID \(tripId) deleted.")
    }

    // MARK: - Event Methods
    func createEvent(with request: EventCreate) async throws -> Event {
        
        let dateFormatter = ISO8601DateFormatter()
        let dateString = dateFormatter.string(from: request.date)
        
        let dataToEncode: [String: Any] = [
            "name": request.name,
            "date": dateString,
            "note": request.note ?? "",
            "location": [
                "latitude": request.location?.latitude ?? 0,
                "longitude": request.location?.longitude ?? 0,
                "address": request.location?.address ?? ""
            ],
            "transition_from_previous": request.transitionFromPrevious ?? false,
            "trip_id": request.tripId
        ]
        
        guard let api = URL(string: "http://localhost:8000/events") else {
            throw URLError(.badURL)
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: dataToEncode.compactMapValues { $0 })
        
        var urlRequest = URLRequest(url: api)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = jsonData
        
        if let tok = token {
            urlRequest.setValue("Bearer \(tok.accessToken)", forHTTPHeaderField: "Authorization")
            print("Using token: \(tok.accessToken)")
        } else {
            print("Token is nil")
        }
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        print("Create event response: \(response)")
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Error creating event: \(errorMessage)")
            throw URLError(.userAuthenticationRequired)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let decodedEvent = try decoder.decode(Event.self, from: data)
            
            guard let tripIndex = trips.firstIndex(where: { $0.id == request.tripId }) else {
                throw URLError(.badServerResponse)
            }
            
            trips[tripIndex].events.append(decodedEvent)
            return decodedEvent
        } catch {
            print("Decoding error while creating event: \(error.localizedDescription)")
            throw error
        }
    }

    func updateEvent(withId eventId: Event.ID, and request: EventUpdate) async throws -> Event {
        
        let (data, response) = try await implementRequest(dataToEncode: request, httpMethod: "PUT", domain: "events", path: "\(eventId)")
        print("Update event response: \(response)")
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Error updating event: \(errorMessage)")
            throw URLError(.userAuthenticationRequired)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let updatedEvent = try decoder.decode(Event.self, from: data)
            
            for tripIndex in trips.indices {
                if let eventIndex = trips[tripIndex].events.firstIndex(where: { $0.id == eventId }) {
                    trips[tripIndex].events[eventIndex] = updatedEvent
                    return updatedEvent
                }
            }
        } catch {
            print("Decoding error while updating event: \(error.localizedDescription)")
            throw error
        }
        
        fatalError("Event update failed: Event not found")
    }

    func deleteEvent(withId eventId: Event.ID) async throws {
        
        let (data, response) = try await implementRequest(dataToEncode: Data(), httpMethod: "DELETE", domain: "events", path: "\(eventId)")
        print("Delete event response: \(response)")
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Error deleting event: \(errorMessage)")
            throw URLError(.userAuthenticationRequired)
        }
        
        for tripIndex in trips.indices {
            for (eventIndex, event) in trips[tripIndex].events.enumerated() where event.id == eventId {
                trips[tripIndex].events.remove(at: eventIndex)
                print("Event with ID \(eventId) deleted.")
                return
            }
        }
        
        fatalError("Event deletion failed: Event not found")
    }

    // MARK: - Media Methods
    func createMedia(with request: MediaCreate) async throws -> Media {
        
        let (data, response) = try await implementRequest(dataToEncode: request, httpMethod: "POST", domain: "media", path: nil)
        print("Create media response: \(response)")
        
        do {
            let decodedMedia = try JSONDecoder().decode(Media.self, from: data)
            
            for tripIndex in trips.indices {
                for eventIndex in trips[tripIndex].events.indices {
                    if trips[tripIndex].events[eventIndex].medias.firstIndex(where: { $0.id == request.eventId }) != nil {
                        trips[tripIndex].events[eventIndex].medias.append(decodedMedia)
                        return decodedMedia
                    }
                }
            }
        } catch {
            print("Decoding error while creating media: \(error.localizedDescription)")
            throw error
        }
        
        fatalError("Create media failed: Media not found")
    }

    func deleteMedia(withId mediaId: Media.ID) async throws {
        
        let (_, response) = try await implementRequest(dataToEncode: Data(), httpMethod: "DELETE", domain: "media", path: "\(mediaId)")
        print("Delete media response: \(response)")
        
        for tripIndex in trips.indices {
            for eventIndex in trips[tripIndex].events.indices {
                if let mediaIndex = trips[tripIndex].events[eventIndex].medias.firstIndex(where: { $0.id == mediaId }) {
                    trips[tripIndex].events[eventIndex].medias.remove(at: mediaIndex)
                    print("Media with ID \(mediaId) deleted.")
                    return
                }
            }
        }
        
        fatalError("Media deletion failed: Media not found")
    }
}


