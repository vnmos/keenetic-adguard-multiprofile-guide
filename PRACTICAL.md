# Практикум: Web CLI, три профиля и проверка stop/start

Этот раздел показывает команды и файлы, а не только устройство решения. Сначала прочитайте границы совместимости в [README](README.md).

## 1. Где вводить команды

В браузере откройте адрес **своего** Keenetic и путь `/webcli/parse`, войдите в панель управления. IP вашей сети в этом руководстве не задан.

- Блоки **Web CLI** вставляются в поле команды по одной строке. Это команды KeeneticOS.
- `exec sh -c "..."` запускает Linux shell из Web CLI. В примерах явно задаётся PATH к среде OPKG.
- Блоки **компьютер** исполняются в локальном терминале, не на роутере.
- Всё в `<УГЛОВЫХ_СКОБКАХ>` заменяется перед отправкой.

После запроса дождитесь завершения, затем прочитайте результат. Ответ `continued: true` не означает, что длительная операция успешно завершена. Старый результат в интерфейсе может ещё относиться к предыдущему запросу.

## 2. Подготовить среду

Сохраните текущую конфигурацию через «Настройки системы → Системные файлы». Держите её вне репозитория. Убедитесь, что умеете восстановить доступ локально.

**Web CLI:**

```text
show version
```

Запишите для себя модель, версию ОС и архитектуру. Не публикуйте весь ответ без просмотра: диагностические команды могут содержать идентификаторы.

Через штатный интерфейс установите OPKG и клиент прокси. Настройте совместимую среду исполнения по документации производителя для своей модели. Установка компонентов может вызвать перезагрузку. Не переносите прошивку или bootstrap-архив с другой архитектуры.

Практические команды ниже предполагают уже подготовленные:

```text
/opt/bin/busybox
/opt/bin/sh
/opt/adguardvpn_cli/adguardvpn-cli
/opt/adguardvpn_cli/ca-certificates.crt
```

CLI берите из [официальных релизов](https://github.com/AdguardTeam/AdGuardVPNCLI/releases), с архитектурой вашего устройства. Проверку подписи выполняйте по разделу Verify Releases [официальной документации](https://github.com/AdguardTeam/AdGuardVPNCLI#verify-releases). CA bundle должен быть из доверенного источника. Бинарные файлы, ключи аккаунта и архивы Entware здесь не распространяются.

**Web CLI, проверка предпосылок:**

```text
exec sh -c "export PATH=/opt/bin:/opt/sbin:/bin:/usr/bin:/sbin; test -x /opt/bin/busybox && test -x /opt/adguardvpn_cli/adguardvpn-cli && test -s /opt/adguardvpn_cli/ca-certificates.crt && echo PREREQUISITES_OK"
```

Ожидается `PREREQUISITES_OK`. Если его нет, дальше не идти. Этот раздел не является универсальным установщиком Entware: на разных поколениях роутеров подготовка отличается.

## 3. Создать первый профиль

Команды ниже создают новый каталог `profile-a`. Если такой профиль уже существует, сначала выясните, кому он принадлежит. Не затирайте его.

**Web CLI:**

```text
exec sh -c "export PATH=/opt/bin:/opt/sbin:/bin:/usr/bin:/sbin; umask 077; mkdir -p /opt/adguardvpn_cli/profiles/profile-a; chmod 700 /opt/adguardvpn_cli/profiles/profile-a"
```

Проверка версии и доступных параметров, с выводом в приватный файл:

```text
exec sh -c "export PATH=/opt/bin:/opt/sbin:/bin:/usr/bin:/sbin; export AGVPN_CLI_DATA_PATH=/opt/adguardvpn_cli/profiles/profile-a; export SSL_CERT_FILE=/opt/adguardvpn_cli/ca-certificates.crt; umask 077; /opt/adguardvpn_cli/adguardvpn-cli --version > /opt/adguardvpn_cli/version.txt 2>&1; /opt/adguardvpn_cli/adguardvpn-cli config --help > /opt/adguardvpn_cli/config-help.txt 2>&1"
```

На стенде использовалась версия 1.7.12. Если версия другая, сверяйте параметры с её справкой.

### Авторизация без SSH

Интерактивную авторизацию нельзя считать законченной только потому, что в браузере открылась страница успеха. Проверяйте ответ CLI на самом роутере.

Следующая команда запускает авторизацию в фоне. Не запускайте её повторно, пока не завершили или не разобрали предыдущую попытку:

```text
exec sh -c "export PATH=/opt/bin:/opt/sbin:/bin:/usr/bin:/sbin; export AGVPN_CLI_DATA_PATH=/opt/adguardvpn_cli/profiles/profile-a; export SSL_CERT_FILE=/opt/adguardvpn_cli/ca-certificates.crt; umask 077; start-stop-daemon -S -b -m -p /tmp/agvpn-login-a.pid -x /opt/bin/sh -- -c '/opt/adguardvpn_cli/adguardvpn-cli login </dev/null > /opt/adguardvpn_cli/login-a.txt 2>&1'"
```

Для чтения текстового файла на встроенном хранилище:

```text
more storage:/adguardvpn_cli/login-a.txt
```

`storage:/` в примерах соответствует встроенному хранилищу стенда. При установке на USB используйте имя своего тома в командах `more`; Linux-пути `/opt/...` при корректном монтировании сохраняются.

Если `more` не читает файл из-за управляющих символов, подготовьте его Base64-представление:

```text
exec sh -c "umask 077; /opt/bin/busybox base64 /opt/adguardvpn_cli/login-a.txt > /opt/adguardvpn_cli/login-a.b64"
more storage:/adguardvpn_cli/login-a.b64
```

Декодируйте текст **локально**, не через сторонний сайт. Base64 не шифрует данные: ссылка и одноразовый код авторизации остаются секретными. Откройте полученную ссылку авторизации AdGuard самостоятельно, проверьте адрес и завершите вход. Не вставляйте ссылку в issue, статью или чат поддержки.

После завершения входа выполните `license` с тем же окружением. Не публикуйте его полный вывод:

```text
exec sh -c "export PATH=/opt/bin:/opt/sbin:/bin:/usr/bin:/sbin; export AGVPN_CLI_DATA_PATH=/opt/adguardvpn_cli/profiles/profile-a; export SSL_CERT_FILE=/opt/adguardvpn_cli/ca-certificates.crt; umask 077; /opt/adguardvpn_cli/adguardvpn-cli license > /opt/adguardvpn_cli/license-a.txt 2>&1"
```

### Настроить SOCKS

**Web CLI:**

```text
exec sh -c "export PATH=/opt/bin:/opt/sbin:/bin:/usr/bin:/sbin; export AGVPN_CLI_DATA_PATH=/opt/adguardvpn_cli/profiles/profile-a; /opt/adguardvpn_cli/adguardvpn-cli config set-mode SOCKS && /opt/adguardvpn_cli/adguardvpn-cli config set-socks-host 127.0.0.1 && /opt/adguardvpn_cli/adguardvpn-cli config set-socks-port 1080 && /opt/adguardvpn_cli/adguardvpn-cli config set-tun-routing-mode NONE && /opt/adguardvpn_cli/adguardvpn-cli config set-change-system-dns off"
```

После каждого этапа проверяйте `config show`. Его вывод тоже держите приватным: там могут быть идентификаторы приложения.

На первом подключении CLI на стенде повторно выставил параметры DNS/маршрутизации. Поэтому проверку `SOCKS`, `NONE`, `off` обязательно повторить **после инициализации соединения**, до включения клиентских маршрутов. Если значения изменились, остановите соответствующий экземпляр, восстановите параметры и запустите его заново. Не допускайте одновременного ручного запуска и запуска supervisor.

## 4. Подготовить ещё два профиля

Повторите создание каталога, авторизацию и настройку для каждой строки:

| Каталог | SOCKS-порт | Параметр локации |
| --- | --- | --- |
| profile-a | 1080 | PROFILE_A_LOCATION |
| profile-b | 1081 | PROFILE_B_LOCATION |
| profile-c | 1082 | PROFILE_C_LOCATION |

В командах авторизации меняйте также имена временного PID-файла и журнала. На рабочем стенде после инициализации первого профиля файл его конфигурации копировался **внутри того же роутера**, без сокетов и журналов, а затем менялись порты. Это не гарантия официальной поддержки клонирования авторизации; здесь не предлагается переносить учётные данные между устройствами.

Локации выбирайте из `list-locations` CLI, с учётом условий своей подписки.

## 5. Перенести сценарии через Web CLI

Файлы:

- [service.sh](service.sh): start/stop/status, защита от двойного запуска и очистка состояния.
- [worker.sh](worker.sh): один дочерний процесс на профиль, проверка соединения и повторные попытки.
- [health.sh](health.sh): SOCKS5-запрос к `example.com`, без данных аккаунта.
- [profiles.example.sh](profiles.example.sh): три заполнителя локаций.

Скачайте файлы репозитория на компьютер. Перед переносом изучите код. Временный HTTP-сервер и SSH не требуются: [make-webcli.py](make-webcli.py) печатает команды для загрузки **только этих четырёх файлов** в отдельный staging-каталог. Он не читает профили и резервные копии.

**Компьютер, в каталоге скачанного репозитория, Python 3:**

```sh
python3 make-webcli.py
```

Вставляйте напечатанные строки по одной в Web CLI. Они записывают файлы в `/opt/adguardvpn_cli/article-stage`, но не запускают VPN и не меняют маршруты. Helper является новой упаковкой способа передачи, применявшегося на стенде; полная установка адаптированного набора на чистом роутере не проверена.

Не заливайте архив всего своего рабочего каталога: там могут находиться секреты.

## 6. Установить сценарии

Ниже предполагается, что все три профиля настроены, а вручную запущенных экземпляров CLI нет. Если VPN уже работает, сначала сохраните старые `service.sh`, `worker.sh`, health-скрипты и `initrc`, выясните способ их штатной остановки. Не применяйте `killall`.

**Web CLI, проверка загруженных файлов:**

```text
exec sh -c "export PATH=/opt/bin:/opt/sbin:/bin:/usr/bin:/sbin; sh -n /opt/adguardvpn_cli/article-stage/service.sh && sh -n /opt/adguardvpn_cli/article-stage/worker.sh && sh -n /opt/adguardvpn_cli/article-stage/health.sh && sha256sum /opt/adguardvpn_cli/article-stage/*.sh"
```

Helper напечатал ожидаемые SHA256. Сверьте их до установки.

**Новая установка, только если `/opt/adguardvpn_cli/boot` ещё отсутствует:**

```text
exec sh -c "export PATH=/opt/bin:/opt/sbin:/bin:/usr/bin:/sbin; umask 077; mkdir /opt/adguardvpn_cli/boot && cp /opt/adguardvpn_cli/article-stage/service.sh /opt/adguardvpn_cli/article-stage/worker.sh /opt/adguardvpn_cli/article-stage/health.sh /opt/adguardvpn_cli/boot/ && cp /opt/adguardvpn_cli/article-stage/profiles.example.sh /opt/adguardvpn_cli/boot/profiles.sh && chmod 700 /opt/adguardvpn_cli/boot/*.sh"
```

Если `mkdir` сообщает, что каталог существует, команда должна остановиться. Не заменяйте её вслепую на `mkdir -p` для перезаписи работающей установки.

Отредактируйте копию `profiles.example.sh` на компьютере, заменив заполнители выбранными значениями. Это shell-файл: значения должны оставаться в кавычках, не вставляйте непроверенные команды. Для переноса готового содержимого кодируйте его локально в Base64 и подставьте в следующую строку:

```text
exec sh -c "umask 077; printf '%s' '<BASE64_OF_YOUR_PROFILES_FILE>' | /opt/bin/busybox base64 -d > /opt/adguardvpn_cli/boot/profiles.sh"
```

Пока заполнители не заменены, `start` вернёт `SET_PROFILE_LOCATIONS`.

## 7. Запустить и проверить

**Web CLI:**

```text
exec sh -c "/opt/bin/sh /opt/adguardvpn_cli/boot/service.sh start"
```

Успешное завершение команды означает только отправку процессов на запуск. Проверка состояния:

```text
exec sh -c "umask 077; /opt/bin/sh /opt/adguardvpn_cli/boot/service.sh status > /opt/adguardvpn_cli/status.txt"
more storage:/adguardvpn_cli/status.txt
```

После установления соединений ожидается:

```text
profile-a: HEALTH_OK
profile-b: HEALTH_OK
profile-c: HEALTH_OK
```

Один `HEALTH_MISS` во время установления соединения не равен окончательному отказу. Если состояние не восстанавливается, изучите приватные журналы `/tmp/agvpn-boot/<PROFILE>/output.log`; не публикуйте их целиком.

Повторно проверьте `config show` для всех профилей, как описано выше. До этой проверки доменные маршруты держите выключенными.

`HEALTH_OK` означает HTTP round-trip через соответствующий SOCKS-порт. Это не проверка всех сайтов, скорости, UDP или отсутствия утечек. `example.com` используется как тестовый адрес; недоступность именно этого узла тоже вызовет ошибки health-check. Для production-пакета стоит предусмотреть свой надёжный набор проверок.

## 8. Добавить штатное прокси-подключение

Сначала прочитайте текущую конфигурацию. Не выбирайте идентификатор занятого объекта.

**Web CLI, отдельные команды:**

```text
interface <FREE_PROXY_ID>
interface <FREE_PROXY_ID> description "Profile A"
interface <FREE_PROXY_ID> security-level public
interface <FREE_PROXY_ID> proxy protocol socks5
interface <FREE_PROXY_ID> proxy upstream 127.0.0.1 1080
interface <FREE_PROXY_ID> down
```

`security-level public` здесь задаёт зону нового исходящего интерфейса Keenetic. Это не команда публикации SOCKS-сервера в интернет. Сам SOCKS остаётся на loopback. Не применяйте эту строку к существующему LAN-интерфейсу.

Аналогично создайте ещё два новых Proxy-объекта с портами 1081 и 1082. Их не нужно назначать общим выходом для всех клиентов.

Создайте группу для собственного тестового домена:

```text
object-group fqdn <FREE_GROUP_ID>
object-group fqdn <FREE_GROUP_ID> description "Test resources A"
object-group fqdn <FREE_GROUP_ID> include <YOUR_TEST_DOMAIN>
dns-proxy route object-group <FREE_GROUP_ID> <FREE_PROXY_ID>
interface <FREE_PROXY_ID> up
show sc dns-proxy route
```

Ожидается одна нужная привязка группы к выбранному Proxy без `disable: true`. Затем сохраните:

```text
system configuration save
```

В «Другие подключения» появится штатный переключатель. Он управляет Proxy-интерфейсом, а не завершает процесс CLI. Проверяйте результат с клиентского устройства в новой сессии, при выключенном VPN на самом клиенте.

## 9. Проверить stop/start без перезагрузки

На время остановки VPN-трафик прервётся. Поведение альтернативного маршрута не является гарантированно fail-closed.

Остановка может ждать до 60 секунд. Для Web CLI используйте фоновую команду и отчёт:

```text
exec sh -c "export PATH=/opt/bin:/opt/sbin:/bin:/usr/bin:/sbin; umask 077; start-stop-daemon -S -b -x /opt/bin/sh -- -c '/opt/bin/sh /opt/adguardvpn_cli/boot/service.sh stop > /opt/adguardvpn_cli/stop-result.txt 2>&1'"
more storage:/adguardvpn_cli/stop-result.txt
```

Дождитесь `STOPPED`. Затем снова выполните `start` из раздела 7 и получите три `HEALTH_OK`. Повторный `start` при работающих процессах должен вывести `ALREADY_RUNNING_OR_PID_CONFLICT` и вернуть код 3, не создавая дубликатов.

На Hopper исправленные рабочие сценарии дали последовательность:

```text
STOPPED
RUNTIME_CLEAN
RESTARTED
<три успешных health-check>
DUPLICATE_START_RC:3
CYCLE_PASS
```

`RUNTIME_CLEAN`, `RESTARTED`, `DUPLICATE_START_RC` и `CYCLE_PASS` печатал тестовый harness, а не сам service.sh. В тесте дополнительно сравнивались PID до и после повторной команды запуска. Приведённый вывод обезличен.

Если появляется `STOP_TIMEOUT`, `SERVICE_BUSY` или `RUNTIME_CLEANUP_FAILED`, не удаляйте весь `/tmp/agvpn-boot` и lock-каталог наугад. Проверьте живые процессы и принадлежность PID. Защитная остановка намеренно предпочтительнее убийства постороннего процесса.

## 10. Автозапуск

На стенде OPKG запускал `/opt/etc/initrc`, который вызывал service.sh. Если ваш initrc уже запускает Entware-службы, сохраните их запуск и добавляйте интеграцию осмысленно. Универсально перезаписывать initrc нельзя.

Содержимое минимального initrc для выделенного стенда без других служб:

```sh
#!/bin/sh
case "${1:-start}" in
start|stop|status)
    exec /opt/bin/busybox sh /opt/adguardvpn_cli/boot/service.sh "${1:-start}"
    ;;
*) exit 2 ;;
esac
```

Сохраните оригинал приватно, установите права на исполнение, затем в OPKG укажите путь к вашему initrc. После согласованной перезагрузки снова получите состояния всех профилей. Предыдущий вариант автозапуска проверялся на обоих стендах; для последнего исправления на Hopper проверен stop/start без перезагрузки. Не смешивайте эти два результата.

## 11. Если на iPhone результат отличается

На iOS 27 проверялся такой паттерн: только Wi-Fi работал, Wi-Fi вместе с сотовыми данными без VPN на телефоне давал другой результат, VPN на телефоне его исправлял.

Отключение **Use Connectivity Assist** в «Настройки → Wi-Fi → информация о выбранной сети» устранило проблему. [Apple описывает](https://support.apple.com/en-gb/guide/iphone/iphw5gjwl8k2/ios) этот параметр как использование сотовых данных дополнительно к Wi-Fi. Точный путь альтернативных запросов в этом эксперименте не измерялся. Это полезный клиентский тест, а не основание сразу менять маршруты всех устройств.

## 12. Откат

1. По фактическому выводу `show sc dns-proxy route` найдите правила этого эксперимента.
2. Отключите только их: `dns-proxy route rule <ACTUAL_RULE_ID> disable`.
3. Переведите созданные Proxy-интерфейсы в `down` и сохраните конфигурацию.
4. Остановите процессы через service.sh; дождитесь завершения.
5. При откате обновления восстановите свои сохранённые сценарии и способ автозапуска. Старый service.sh с известной ошибкой lock-каталога не становится исправным от восстановления файла.

Не удаляйте данные авторизации, настройки WAN, общую таблицу маршрутов или файлы других служб. Полная конфигурация роутера и резервная копия `/opt` решают разные задачи восстановления.
