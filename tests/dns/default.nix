{
  self,
  inputs,
  mylib,
  system,
  ...
} @ args: let
  dns_test = {
    resolver_ipv4 = "192.0.2.2";
    probe_ipv4 = "192.0.2.3";
    subnet_cidr = "192.0.2.0/24";
    tld = "vm.test";
    alpha_host = "alpha.vm.test";
    beta_host = "beta.vm.test";
    alpha_target = "alpha";
    beta_target = "beta";
    alpha_body = "dns-suite-alpha-body";
    beta_body = "dns-suite-beta-body";
    pihole_password = "dns-suite-password";
    pihole_password_hash = "11bcea9d00dbe5e68c793d7af6a282adbfa53786e1c0170eee8d5012e549676c";
    fixture_port = 18080;
    alpha_backend_port = 18081;
    beta_backend_port = 18082;
    tls_cert = ''
      -----BEGIN CERTIFICATE-----
      MIIDYDCCAkigAwIBAgIUUrL9E3fhADVLiaE+bKKXGw2RyRowDQYJKoZIhvcNAQEL
      BQAwGDEWMBQGA1UEAwwNYWxwaGEudm0udGVzdDAeFw0yNjA1MDMwNjQ3MzRaFw0z
      NjA0MzAwNjQ3MzRaMBgxFjAUBgNVBAMMDWFscGhhLnZtLnRlc3QwggEiMA0GCSqG
      SIb3DQEBAQUAA4IBDwAwggEKAoIBAQCXxBX5+o1OPYEZHDSPEV9E8qNUQ7elqhdD
      kTMJ5ip5DUqeXapuWpWsajgm2cn0hEBh5FEQea34zgN1VELY6uCkPqHHRvJWFuVJ
      GqEXUn7OqqjpAusX75WJUQLsHRephrNqelfDKNYBK/B3lRLJWJKJ3g5nxEpIJyhh
      ejUJIm0sjakWZ3u5h7CMg8+jagZ/pRFkDj3EnOEyRwIZDG4gYY1y0nYWr99InqUq
      4VOa7LTTPi2tyCPfsVgroV+6gqwcJofGB6gAE0zN3tR21jmtnpP/FKeq+wugPi69
      KuAFCxhgkw1FFm/1O9gFJ4TOnbCxNLTZDGOfAQ3OidK3JYTTO8t9AgMBAAGjgaEw
      gZ4wRwYDVR0RBEAwPoINYWxwaGEudm0udGVzdIIMYmV0YS52bS50ZXN0gg5waWhv
      bGUudm0udGVzdIIPdHJhZWZpay52bS50ZXN0MA8GA1UdEwEB/wQFMAMBAf8wDgYD
      VR0PAQH/BAQDAgKkMBMGA1UdJQQMMAoGCCsGAQUFBwMBMB0GA1UdDgQWBBR/QGch
      lRPMBWDUEm8B1/lUqn/oYjANBgkqhkiG9w0BAQsFAAOCAQEAlhtNrxrCgIhF0z0a
      Y7wV3l0k1KA5gYFBH8i0dPsxT+rwkPnCeMXogveDm6MVtUw8O8bf+7t3DUh2faRd
      CKSVdUAJhz2oPvJVr+5BlvJQbMVrz9ycNb0stdth6yLnUDl/wByQgUXPjfj1KYgZ
      +HxpDiZqkg2Ja57EDg1rzFC92jofYOuQ9KbOXsj7w3boT/mJab9guYZiKQRSF3VI
      aFEtYCKAUoC6is+u+SnpNZgBKuj4qEv2PhPoBkXYJSpxZzvgx326EYnHkidb8Qau
      sIAK+L1AC1GBEFYV1ROxTzkQuKiwE2Hs3BaGfC+0y+6/DqJQ8OFWT2CZIQMdoW70
      VP4xPg==
      -----END CERTIFICATE-----
    '';
    tls_key_b64 = "LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCk1JSUV2QUlCQURBTkJna3Foa2lHOXcwQkFRRUZBQVNDQktZd2dnU2lBZ0VBQW9JQkFRQ1h4Qlg1K28xT1BZRVoKSERTUEVWOUU4cU5VUTdlbHFoZERrVE1KNWlwNURVcWVYYXB1V3BXc2FqZ20yY24waEVCaDVGRVFlYTM0emdOMQpWRUxZNnVDa1BxSEhSdkpXRnVWSkdxRVhVbjdPcXFqcEF1c1g3NVdKVVFMc0hSZXBock5xZWxmREtOWUJLL0IzCmxSTEpXSktKM2c1bnhFcElKeWhoZWpVSkltMHNqYWtXWjN1NWg3Q01nOCtqYWdaL3BSRmtEajNFbk9FeVJ3SVoKREc0Z1lZMXkwbllXcjk5SW5xVXE0Vk9hN0xUVFBpMnR5Q1Bmc1Zncm9WKzZncXdjSm9mR0I2Z0FFMHpOM3RSMgoxam10bnBQL0ZLZXErd3VnUGk2OUt1QUZDeGhna3cxRkZtLzFPOWdGSjRUT25iQ3hOTFRaREdPZkFRM09pZEszCkpZVFRPOHQ5QWdNQkFBRUNnZ0VBUko3d011SFRmNU4ycW1SaTdXZDA5S2RqSzBnZEl1Wlg4NENWRzc0NjZSWVYKN2FvN1UvOVlXcWVDY1NxYlVwaHp4ZTltcWZUaXNUTnhROTFRQm1XWklocUJxcW1OREZqNDNrZVFuQXQ4YzdTZApnQklHTzRIa1VyelMvZkNma05Mcmo5TDJtTEwvcEhMNkhRL0YrVTAzb09mTENxY3AwUnNIZXArM21FUTlLZDNHCjQ3UnlySCtLek1KbDhLbGRieDFEUlAyVWRrOTFNbVBrQkJGb2JYZXZMczBqZi9xRnY4N2ZWdGJ6ZWNjeFBGOEsKM0FNSnFEUjBVaHc0c2lKdXJQcWtkUVdscGdDQTNJdUZFQVl0K1R5Q3c2TDVwVjNUeU1GeHVZeVZPckdwdklLTgpaWWJ3RE5qT3M2azk0bFpaRU1EUzdRWERjdS9tL3krT0Z4WGRZWWJUYndLQmdRRFVDWVZUVlBCTGVtOVJKVzc5CmtnbkczOGJobXRrSVNpckJUdWl2LzRBTi9oZndJajhvMGUxemlvL05BaE9PdHRnUHdQb0hTQnlMQmROMjFjSjAKK2h3ZEx1bS9mUHh3TG1kdENmcTVXelN3c2gwL0FRT1l5TkhzRnFCaDhHbW51V2VQNmJROGZQMGVEek9pYkFSZgpPWHJ2aWtTbXdFWngwV3NIczQ0NXUxWG1Wd0tCZ1FDM08zOVlGZjJMeDdWR25paXFoaHl2WmZwcWJFdkJGTWhnClVxbzduenRoKzh5VXNUYmx3cHl4SE0rRVArS1BwWHA1SEdVVVlPVDJ4Q3NndzZjeGxDbEorZDJxZkdTRUgzY2QKR1FuRnkyTlJXNldKa1VzYXlUNTZMdUxMbU8rZTZnc0x6Wmxkb28rVmtIRm9HZmVxMlB0a2E3eXdRNFg1emhORgpNMmk5MG9jd1N3S0JnRnJaZVhhcS9ncFkremtaZ09URW5jdklOYjZVU2tseS9iNjF3SjBvTEFYU3lRN3FuWVV2CjdUMkVNUGoxMnN0YkxGZ1RwdzFYcUdNb3ErSk8xSEtxZDBGSnlIMXpYL1h3Ni8rY053RVVRdzh5UWJXdENZMTgKL2ZUWi9QMzV0RXRZOVRhRU8rVnU2RVRvM29iSklWWnJtbkRvSFdJVklCbkVVTWVMOTNSay8va2hBb0dBSmxFNQo0eWpPR2RJTWxaVHplaDJMbUI1aVRLa1MrbkNuS29WKzlmTHBqeWNCOUVKTzhhTk44emZNS2FMV2RTV3N3L0R0CkxtTEkzdFhORXcvM1FjWHpFSFpCSmFyWHRrMkNNa0tQS1o3THlUSzZIbGVVOWlnSmViR2VXZWRFak4zeXEyZzIKWHo5a2VXbDRYY1c0WmpEeitWOFNXV1gxZVhUZjBNUGNibjI5S1pzQ2dZQm1OVFBmSFN5RGRkTW1qTGNtR3RpYQpYZGY1SytLbGVxVm5ZZzdoSWRId1VwSGJNUkJNNjNIYStudUdhQ1FheUpxbkRvNUFzZHh6UFR6UWNTSlVtdzY1ClVMK1lva3NHK3FXL0FSVXJrOVR4Y1dIRnZoZTlDV0krZHhyZ09CcVk2aGdYdEhQM1ZXQzk3K1h4ZDlsMmVhaVQKcHNXOVdvVDJtYURMc24ydFRSQWVydz09Ci0tLS0tRU5EIFBSSVZBVEUgS0VZLS0tLS0K";
  };
in
  mylib.tests.mk_test {
    # Two-node DNS topology: resolver runs Pi-hole, OctoDNS, Traefik, local fixture
    # services, and mock HTTP backends; probe validates API auth, DNS answers, and
    # HTTPS routing against deterministic local-only names and certificates.
    name = "dns";
    python_module_name = "dns";

    node.pkgsReadOnly = false;
    node.specialArgs = {
      inherit self inputs mylib system dns_test;
    };

    nodes = {
      resolver = import ./resolver.nix args;
      probe = import ./probe.nix args;
    };
  }
