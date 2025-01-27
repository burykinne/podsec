podsec-create-imagemakeruser(1) -- создание пользователей разработчиков образов контейнеров
================================

## SYNOPSIS

`podsec-create-imagemakeruser [имя_пользователя[@тропа_репозитория]] ...`

## DESCRIPTION

Cкрипт создает пользователей разработчиков образов контейнеров, обладающими правами:
- менять установленный администратором безопасности средства контейнеризации пароль;
- создавать, модифицировать и удалять образы контейнеров.

При создании каждого пользователя необходимо задать:

- `пароль пользователя`;

-  `тип ключа`: `RSA`, `DSA и Elgamal`, `DSA (только для подписи)`, `RSA (только для подписи)`, `имеющийся на карте ключ`;

- `срок действия ключа`;

- `полное имя`;

- `Email` (используется в дальнейшем для подписи образов);

- `примечание`;

- `пароль для подписи образов`.

Скрипт должен вызываться после вызова скрипта `podsec-create-policy`


## OPTIONS

Список пользователей и тропы регистратороы для которых они подписывают образы передаются параметрами в формате:
`имя_пользователя@тропа_репозитория`

- В списке не должно быть пользователей с одинаковыми тропами.

- Если пользователь единственный и тропа не указана, то принимается тропа `registry.local`

- Если имя пользователя не указано первым параметром принимается имя `imagemaker@registry.local`.

## EXAMPLES

`podsec-create-imagemakeruser immkk8s@registry.local/k8s-p10 imklocal@registry.local  immkalt@registry.altlinux.org`

Создаются три пользователя с правами на подпись:

- `immkk8s` - локальных образов kubernetes с тропой `registry.local/k8s-p10`;

- `imklocal` - локальных образов `registry.local` за исключением образов kubernetes

- `immkalt` - образов регистратора `registry.altlinux.org`



## SECURITY CONSIDERATIONS

- Данный скрипт должен запускаться только на узле с доменами `registry.local`, `sigstore-local`. Если это не так, скрипт прекращает свою работу.

- Пользователи разработчики образов должны сами контролировать список подписываемых образов. Если пользователь `imklocal` подпишет образ с тропой `registry.local/k8s-p10`, то разворачивание данного образа будет неуспешным, так как при проверке подписи будет использоваться открытый ключ пользователя  `immkk8s`, а не `imklocal`.

- Все создаваемые в кластере пользователи должны располагаться на одном сервере с доменом `storage.local`. Там же должен быть развернут WEB-сервер подписей образов.

- Все открытые ключи пользователей располагаются в каталоге `/var/sigstore/keys/` и должны быть скопированы на каждый сервер кластера к каталог `/var/sigstore/keys/`

- Подписи образов хранятся в каталоге  `/var/sigstore/sigstore/` с отброшенными именами регистраторов. Таким образом, если в системе контролируются подписи образов с разных регистраторов (например: `registry.altlinux.org` и `registry.local`) и образ `registry.local/k8s-p10/pause:3.7` c `@sha256\=347a15493d0a38d9ce74f23ea9f081583728a20dbdc11d7c17ef286d9cade3ec` подписан, то будут считаться подписанными все образы с данным `sha256`: `registry.altlinux.orh/k8s-p10/pause:3.7`, ...

## SEE ALSO

- [Разработчик образов контейнеров (imagemaker)](https://github.com/alt-cloud/podsec/tree/master/SigningImages).

- [Описание периодического контроля целостности образов контейнеров и параметров настройки средства контейнеризации](https://github.com/alt-cloud/podsec/tree/master/ImageSignatureVerification)

## AUTHOR

Костарев Алексей, Базальт СПО
kaf@basealt.ru
