class_name Sfx
extends AudioStreamPlayer
## ДУУ ГАРГАГЧ — гаднаас дууны файл ашиглахгүй.
## Ретро "бип" дууг кодоор (квадрат долгион) үүсгэнэ.
## Жишээ: Game.sfx.beep(440, 0.1)  → 440 Гц, 0.1 секунд

const RATE := 22050   # Секундэд хэдэн дээж


func beep(freq: float, dur: float, vol := 0.25) -> void:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n)
	for i in n:
		# Квадрат долгион: хагас үед +1, хагас үед -1
		var wave := 1.0 if fmod(i * freq / RATE, 1.0) < 0.5 else -1.0
		# Аажмаар намсгах (envelope) — "тас" гэж таслахгүй
		var env := 1.0 - float(i) / n
		var sample := int(wave * env * vol * 127.0)
		data[i] = sample & 0xFF   # signed 8-bit → byte
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = RATE
	wav.data = data
	stream = wav
	play()
