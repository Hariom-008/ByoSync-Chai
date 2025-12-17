import SwiftUI

struct ChaiUpdateView: View {
    @State private var vm = ChaiViewModel()
    @Binding var userId: String

    var body: some View {
        VStack(spacing: 20) {
            Text("Chai Chain")
                .font(.title2).bold()

            ChaiMeter(chai: vm.chai, isLoading: vm.isLoading)
                .frame(height: 140)

            Button {
                Task { await vm.updateChai(userId: userId) }
            } label: {
                HStack {
                    if vm.isLoading {
                        ProgressView().padding(.trailing, 6)
                    }
                    Text(vm.isLoading ? "Updating..." : "Update Chai")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .disabled(vm.isLoading || userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .buttonStyle(.borderedProminent)

            if let msg = vm.lastMessage {
                Text(msg)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            if let err = vm.lastError {
                Text(err)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }

            Spacer()
        }
        .padding()
        .animation(.easeInOut(duration: 0.2), value: vm.lastMessage)
        .animation(.easeInOut(duration: 0.2), value: vm.lastError)
    }
}

// MARK: - Animated Meter

private struct ChaiMeter: View {
    let chai: Int          // 0...5
    let isLoading: Bool

    @State private var pulse = false
    @State private var spin = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Ring background
                Circle()
                    .stroke(lineWidth: 10)
                    .opacity(0.15)

                // Ring progress (0..1)
                Circle()
                    .trim(from: 0, to: CGFloat(chai) / 5.0)
                    .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: chai)

                // Center content
                VStack(spacing: 6) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 26))
                        .rotationEffect(isLoading ? .degrees(spin ? 360 : 0) : .degrees(0))
                        .animation(isLoading ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default, value: spin)

                    Text("\(chai)/5")
                        .font(.title3).bold()
                }
                .scaleEffect(pulse ? 1.06 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.55), value: pulse)
            }
            .frame(width: 120, height: 120)

            // 5-cup indicator row
            HStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { i in
                    Image(systemName: i < chai ? "cup.and.saucer.fill" : "cup.and.saucer")
                        .font(.system(size: 18))
                        .scaleEffect(i == chai - 1 && pulse ? 1.15 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: chai)
                }
            }
        }
        .onAppear {
            spin = true
        }
        .onChange(of: chai) { _, _ in
            // quick pulse on each successful increment
            pulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { pulse = false }
        }
    }
}

