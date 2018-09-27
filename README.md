```

В Facebook-аккаунте создано Application:
APP ID: 1205983529456424

Приложение требуется для доступа к Facebook API:
https://graph.facebook.com/

Процесс (thread) периодически запрашивает FB-API на предмет получения постингов, далее новые постинги сохраняются в локальной БД (SQLite).

В OTRS для создания тикетов используется Web-sevice:
https://metacpan.org/pod/App::OTRS::CreateTicket

Для 'обратной связи' (т.е. для постинга в FB  комментариев к тикету из OTRS) планируется использовать web-сервис (REST), запущенный на том же сервере.
Web-сервис принимает REST-запрос, находит (в локальной БД) по ticket_id соответсвующий ему FB-постинг.
Для создания комментария к постингу будет исползоваться POST-запрос на URL вида:
https://graph.facebook.com/{post_id}/comments/?access_token={token}&message=message_text

Для получения (обновления) token'а доступа необходимо использовать GET-запрос такого вида:
https://graph.facebook.com/oauth/access_token?grant_type=fb_exchange_token&client_id=APP_ID&client_secret=APP_SECRET&fb_exchange_token=ACCESS_TOKEN
В ответ FB выдает следующее:
access_token=NEW_ACCESS_TOKEN&expires=EXPIRES_IN_SECONDS


```
