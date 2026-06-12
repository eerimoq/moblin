import SwiftUI

struct GeminiOverlayView: View {
    @ObservedObject var model: Model
    let previewSize: CGSize
    
    var body: some View {
        ZStack {
            // 1. Image Overlay
            if let imageURLString = model.geminiOverlayImageURL, let imageURL = URL(string: imageURLString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: previewSize.width * 0.8, maxHeight: previewSize.height * 0.8)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    case .failure(_):
                        EmptyView()
                    case .empty:
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    @unknown default:
                        EmptyView()
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: model.geminiOverlayImageURL)
            }
            
            // 2. Text Overlay (Notification banner)
            if let overlayText = model.geminiOverlayText {
                VStack {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.yellow)
                            .font(.title3)
                        
                        Text(overlayText)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                    .padding(.top, 40)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    
                    Spacer()
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: model.geminiOverlayText)
            }
            
            // 3. Voice Listening Panel
            if model.isGeminiListening {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .opacity(model.geminiSpeechText == "Processando..." ? 0.3 : 1.0)
                                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: model.isGeminiListening)
                            
                            Text("Gemini AI")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                        }
                        
                        Text(model.geminiSpeechText)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: min(previewSize.width - 32, 400))
                    .background(.ultraThinMaterial)
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: model.isGeminiListening)
            }
        }
        .frame(width: previewSize.width, height: previewSize.height)
    }
}
