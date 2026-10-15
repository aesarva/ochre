# StatusApp

Системный монитор в строке меню macOS (CPU, память, диск, сеть, GPU, батарея, датчики, процессы) на Liquid Glass. Главный элемент — карта кристалла: ядра CPU по кластерам и полоса GPU, подсвеченные по нагрузке; в строке меню — её мини-копия. Цвет в интерфейсе означает только нагрев: янтарь → угли → жар.

- Требования: macOS 26+, Xcode (Swift 6.2+). Если `xcode-select` указывает на Command Line Tools, перед командами задайте `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- Тесты: `swift test`.
- Сборка: `scripts/build-app.sh` собирает universal `build/StatusApp.app` (arm64 + x86_64, hardened runtime, ad-hoc подпись). Только Apple Silicon: `ARCHS=arm64 scripts/build-app.sh`.
- Установка: скопируйте `build/StatusApp.app` в `/Applications` и запустите; приложение живёт только в строке меню (`LSUIElement`).
- Оповещения (температура CPU, загрузка CPU, давление памяти, свободное место) настраиваются в окне настроек; при срабатывании показывается системное уведомление и красная подсветка. Разрешите уведомления при первом запросе.
- Температура обновляется раз в 15 с, пока панель закрыта (экономия CPU); при открытой панели интервал 2 с.
- Отладочные аргументы запуска: `-OpenPopoverOnLaunch YES` (открыть панель), `-PopoverTab <вкладка>` (стартовая вкладка), `-SnapshotDir <путь>` (сохранить PNG строки меню, вкладок и настроек для отладки).
- Известные ограничения: датчики читаются через приватные API (SMC/IOHID) и могут отличаться между моделями Mac; на Intel-маках температуры недоступны (там нет HID-датчиков), вентиляторы и мощность читаются через SMC; процессы других пользователей и root недоступны, они пропускаются.

## Релиз

Приложение распространяется вне App Store (приватные API датчиков туда не допускаются): DMG, подписанный Developer ID и нотаризованный Apple, открывается у пользователей обычным двойным кликом.

Однократная подготовка:
1. Вступить в [Apple Developer Program](https://developer.apple.com/programs/).
2. Создать сертификат **Developer ID Application**: Xcode → Settings → Accounts → Manage Certificates → «+». Проверка: `security find-identity -v -p codesigning`.
3. Создать пароль приложения на [account.apple.com](https://account.apple.com) (Вход и безопасность → Пароли приложений) и сохранить профиль нотаризации:
   ```
   xcrun notarytool store-credentials StatusApp --apple-id <apple-id> --team-id <TEAMID> --password <пароль-приложения>
   ```

Выпуск версии: `scripts/release.sh 1.0.0` → `dist/StatusApp-1.0.0.dmg` (сборка, подпись, нотаризация приложения и DMG, проверка Gatekeeper). Сертификат берётся из связки ключей автоматически; если их несколько — `SIGN_IDENTITY="Developer ID Application: …"`. Без сертификата `scripts/release.sh 1.0.0 --unsigned` проверяет всё, кроме подписи и нотаризации.

Идентификатор приложения — `com.alexsarva.StatusApp`; настройки сборок со старым `local.statusapp.StatusApp` переносятся при первом запуске.

## Сайт

Лендинг — статическая страница `site/` (HTML/CSS/JS без сборки, все пути относительные, поэтому папку можно положить под любым путём, например `/statusapp/`). Локальный просмотр: `cd site && python3 -m http.server`. Перед публикацией положите `dist/StatusApp.dmg` (его создаёт `scripts/release.sh`) рядом с `site/index.html`: на него ведут кнопки «Скачать». Публикуйте сайт после нотаризации — в характеристиках указано «Developer ID, проверено Apple».
