import SwiftUI
import WeatherCore

struct LiveWeatherSettingsView: View {
    @ObservedObject var service: LiveWeatherService
    @Binding var enabled: Bool
    @Binding var city: WeatherCity?
    @Binding var fallback: WeatherMode
    @State private var query = ""

    var body: some View {
        GroupBox("실제 날씨") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("실제 날씨에 맞춰 효과 바꾸기", isOn: $enabled)
                    .toggleStyle(.switch)
                Text("선택한 도시의 날씨를 약 15분마다 확인합니다. 도시 검색어와 선택 도시의 좌표를 Open-Meteo에 전송하며, 기기의 현재 위치는 조회하지 않습니다.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if enabled {
                    if let city {
                        Label(city.displayName, systemImage: "mappin.and.ellipse")
                            .font(.callout).textSelection(.enabled)
                    }
                    HStack {
                        TextField("도시 이름 · 예: 서울, Busan", text: $query)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { service.search(query) }
                            .accessibilityLabel("날씨를 연동할 도시 검색")
                        Button("검색") { service.search(query) }
                            .disabled(service.isSearching || query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                        if service.isSearching { ProgressView().controlSize(.small) }
                    }
                    if let searchError = service.searchError {
                        Text(searchError).font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(service.searchResults) { result in
                        Button {
                            city = result
                            service.cancelSearch()
                            query = ""
                        } label: {
                            HStack {
                                Text(result.displayName).multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "plus.circle")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                    }
                    Picker("비·눈이 없을 때", selection: $fallback) {
                        ForEach(WeatherMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    Text(service.status).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let date = service.lastUpdated {
                        Text("날씨 기준: \(date.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack {
                        if let until = service.manualUntil {
                            Button("자동 연동 재개", action: service.resumeAutomatic)
                            Text("\(until.formatted(date: .omitted, time: .shortened))까지 수동")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Button("지금 날씨 확인") { service.refresh(force: true) }
                                .disabled(city == nil || service.isFetching)
                        }
                        if service.isFetching { ProgressView().controlSize(.small) }
                    }
                    Text("직접 효과를 고르면 30분 동안 유지합니다. 날씨 연결이 끊기면 최근 값을 최대 1시간 유지한 뒤 기본 효과로 돌아갑니다.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 5) {
                    Text("날씨 데이터:")
                    Link("Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
                    Text("· 효과로 변환 ·")
                    Link("CC BY 4.0", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!)
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
