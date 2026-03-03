ffplay tcp://192.168.178.35:5000 -vf "setpts=N/30" -fflags nobuffer -flags low_delay -framedrop
