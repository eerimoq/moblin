import Foundation
import AuthenticationServices
import SwiftUI
import Twitch


class StreamTwitchSettingsViewController: UIViewController, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return self.view.window ?? ASPresentationAnchor()
    }
}

struct TwitchUserData: Decodable {
    let data: [UserData]
}

struct UserData: Decodable {
    let id: String
    let login: String
}

class TwitchAuth {
    private var model: Model
    @State private var authSession: ASWebAuthenticationSession?
    
    let authorizationUrl = "https://id.twitch.tv/oauth2/authorize"
    let twitchClientId = "ndtuabi5wzhedsj53ol9swcnobmti7"
    let twitchScopes = "user:edit+user:read:chat+user:write:chat+moderator:manage:announcements+channel:bot+user:bot"
    let twitchRedirectURI = "https://nofuture2077.github.io/moblin/auth/"
    
    init(model: Model) {
        self.model = model
    }
    
    func startAuthentication(stream: SettingsStream) {
        guard let encodedRedirectURI = twitchRedirectURI.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
            return
        }
        
        let urlString = "\(authorizationUrl)?client_id=\(twitchClientId)&redirect_uri=\(encodedRedirectURI)&response_type=token&scope=\(twitchScopes)"
         
        if let url = URL(string: urlString) {
            let viewController = StreamTwitchSettingsViewController()
            let authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: "moblin") { callbackURL, error in
                
                guard error == nil, let cb = callbackURL else {
                    logger.info("Authentication failed: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                if let token = self.extractToken(from: cb) {
                    stream.twitchAccessToken = token
                    self.model.store()
                    
                    let configuration = URLSessionConfiguration.default
                    
                    self.fetchUsernameAndId(clientId: self.twitchClientId, accessToken: token) { username, userId in
                        if let username = username, let userId = userId {
                            stream.twitchChannelName = username
                            stream.twitchChannelId = userId
                            self.model.store()
                            Task {
                                do {
                                    let twitchClient = try self.twitchClient(stream: stream)
                                    try await twitchClient!.sendAnnouncement(broadcasterId: userId, message: "moblin connected")
                                } catch {
                                    logger.error(error.localizedDescription)
                                }
                            }
                        } else {
                            logger.info("Failed to fetch username and ID.")
                        }
                    }
                }
            }
            authSession.presentationContextProvider = viewController
            authSession.prefersEphemeralWebBrowserSession = true
            authSession.start()
            self.authSession = authSession
        }
    }
    
    func twitchClient(stream: SettingsStream) throws -> Helix? {
        guard (stream.twitchAccessToken != nil) else {
            return nil
        }
        return try Helix(
            authentication: .init(oAuth: .init(stream.twitchAccessToken!), clientID: self.twitchClientId, userId: stream.twitchChannelId)
        )
    }
    
    func fetchUsernameAndId(clientId: String, accessToken: String, completion: @escaping (String?, String?) -> Void) {
        guard let url = URL(string: "https://api.twitch.tv/helix/users") else {
            completion(nil, nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(clientId, forHTTPHeaderField: "Client-ID")
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                logger.info("Error: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil, nil)
                return
            }
            
            do {
                let twitchData = try JSONDecoder().decode(TwitchUserData.self, from: data)
                if let userData = twitchData.data.first {
                    completion(userData.login, userData.id)
                } else {
                    logger.error("Error: No user data found in the response.")
                    completion(nil, nil)
                }
            } catch {
                logger.error("Error: \(error.localizedDescription)")
                completion(nil, nil)
            }
        }
        
        task.resume()
    }
    
    func extractToken(from url: URL) -> String? {
        if let fragment = url.fragment {
            let components = fragment.components(separatedBy: "&")
            for component in components {
                let keyValue = component.components(separatedBy: "=")
                if keyValue.count == 2 && keyValue[0] == "access_token" {
                    let accessToken = keyValue[1]
                    return accessToken;
                }
            }
        }
        return nil;
    }
}
