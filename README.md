===========================================================================
   PROJECT ZOMBOID - MOD TIKANIKLIGI ACICI
   (Coop / Host sunucusu acilmiyorsa)
===========================================================================

NE ISE YARAR
------------
Coop sunucusu baslatirken su hatayi aliyorsaniz:

    "Sunucu baslatilma esnasinda durduruldu (NormalTermination)"

...ve atolye ogeleri yuklenirken belirli bir sirada takiliyorsa,
bu arac tikanikligi acar.

Sunucu log'unda sunlari goruyorsaniz kesinlikle bu sorundur:
    Workshop: onItemNotDownloaded itemID=... result=33
    Workshop: onItemNotDownloaded itemID=... result=2
    Workshop: item state DownloadPending -> Fail ID=...
    java.lang.NullPointerException
        at zombie.network.GameServerWorkshopItems.Install(...)

(Log konumu: Belgeler disinda -> C:\Users\<KULLANICI>\Zomboid\Logs\
 en son "..._DebugLog-server.txt" dosyasi)


SORUNUN SEBEBI
--------------
Project Zomboid'in coop sunucusu, Steam istemcinizden AYRI bir atolye
kaydi tutar:

    ...\steamapps\common\ProjectZomboid\steamapps\workshop\appworkshop_108600.acf

Bir mod Steam istemcinizde kurulu oldugu halde bu AYRI kayitta "kurulu"
olarak isaretli degilse, sunucu o modu yeniden indirmeye calisir.
Ama ayni modu Steam istemcisi de yonetmektedir -> kilit catismasi olusur:

    result=33 = k_EResultLockingFailed
                ("Failed to acquire access lock for this operation")

Indirme basarisiz olunca PZ'nin temizleme kodu NullPointerException ile
coker ve sunucu kapanir.

Kiralik sunucularda bu olmaz, cunku orada yaninda calisan bir Steam
istemcisi yoktur. Sorun modlarinizda DEGILDIR.


BU ARAC NE YAPAR
----------------
1. Steam ve Project Zomboid kurulumunu OTOMATIK bulur
   (kayit defterinden + libraryfolders.vdf ile tum kutuphaneleri tarar,
    farkli disklerdeki kurulumlari da bulur)
2. Sunucunun ayar dosyalarindan (Zomboid\Server\*.ini) hangi modlara
   ihtiyac duydugunu okur
3. Steam istemcinizin KENDI kayitlarini kaynak alarak eksik "kurulu"
   kayitlarini sunucunun kaydina ekler
4. Eksik mod icerigini Steam klasorunden sunucu klasorune KOPYALAR
5. Askida kalmis indirme isaretlerini temizler

HICBIR SEY INTERNETTEN INDIRILMEZ. Butun degerler (boyut, manifest)
Steam'in kendi kayitlarindan alinir - hicbir sey uydurulmaz.


NASIL KULLANILIR
----------------
1. Project Zomboid'i TAMAMEN kapatin
2. "PZ Mod Tikanikligi Ac.bat" dosyasina cift tiklayin
3. Ekrandaki ozeti okuyun, onaylamak icin E yazip Enter'a basin
4. Bitince: Steam'i kapatip acin -> oyunu acin -> sunucuyu baslatin

Yonetici olarak calistirmaniz genelde GEREKMEZ.
Eger "erisim reddedildi" hatasi alirsaniz .bat dosyasina sag tiklayip
"Yonetici olarak calistir" secin.


GUVENLIK
--------
- Oyun acikken calismaz (kendini durdurur)
- Degisiklik yapmadan ONCE masaustune tam yedek alir:
      PZ_AtolyeKayit_Yedek_<tarih_saat>\appworkshop_108600.acf
- Yazmadan once dosya yapisini dogrular; bozulacaksa hicbir sey yazmaz
- Sadece sunucunun ayar dosyasinda GERCEKTEN istenen modlara dokunur
  (eski yapilandirmalardan kalan yuzlerce MB'lik ogeleri kopyalamaz)

GERI ALMA:
Yedek klasorundeki appworkshop_108600.acf dosyasini su konuma
geri kopyalayin:
    ...\steamapps\common\ProjectZomboid\steamapps\workshop\


SIKCA SORULANLAR
----------------
S: "Duzeltilecek bir sey yok" diyor ama sunucu yine acilmiyor.
C: Sorun baska bir yerde. Sunucu log'unu kontrol edin - "result=" satiri
   yoksa bu araci ilgilendiren sorun degildir.

S: Sunucu ayar dosyasi bulunamadi diyor.
C: Coop sunucusunu bir kez baslatmayi deneyin (kapansa bile). Ayar
   dosyasi olusacak, sonra araci tekrar calistirin.

S: Her mod guncellemesinde tekrar mi calistirmam gerekiyor?
C: Genelde hayir. Ama kendi modunuzu atolyeye her yukledigunuzde bu
   durum tekrar olusabilir - o zaman tekrar calistirin.

S: Arkadaslarim da mi calistirmali?
C: Sadece SUNUCUYU ACAN kisi calistirmali. Katilan oyuncular normal
   sekilde Atolye'den abone olur, onlarda bu sorun olusmaz.

===========================================================================
