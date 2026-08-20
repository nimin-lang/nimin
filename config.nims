switch("path", "$nim")
switch("define", "nimcore")
# The nimin driver installs the `strongSemCheck` hook. The compiler only calls
# that hook (and `compatibleProps`) when built with `-d:drnim`.
switch("define", "drnim")