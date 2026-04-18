Tower of Hanoi ima pravilniju strukturu i optimalno rješenje dužine 2^n - 1, pa je formalnom alatu lakše da ga pretražuje. Panex je znatno teži problem. Već za male vrijednosti S broj poteza brzo raste, npr. za S=4 Panex zahtijeva 128 poteza, dok Tower of Hanoi za n=4 zahtijeva 15 poteza, pa dolazi do mnogo veće eksplozije stanja. Zbog toga je za Panex pogodnije koristiti heuristike i redukcione tehnike koje usmjeravaju alat ka cilju.

Iako pojedini dijelovi modela imaju linearnu složenost, samo rješavanje Panexa je eksponencijalno i zato je problem težak za formalni alat. Jednostavne heuristike koje sam probala nisu dale zadovoljavajuće rezultate. U materijalu su navedene tehnike kao što su redukcija, tačke presjeka, case split i pojednostavljenje okruženja. U mom slučaju case split daje upotrebljive rezultate samo do S=3.

Zbog toga sam se odlučila za pristup sa oracle checkpointima. Ideja nije da formalnom alatu dam kompletnu ulaznu sekvencu i samo provjerim rezultat, nego da mu zadam checkpoint stanja izvedena iz oracle rješenja i restrikcije tako da između uzastopnih checkpointova mora doći u ograničenom broju koraka. Time se pretraga usmjerava, a veliki broj nebitnih grana se odbacuje. To je bio najbolji trade-off između ograničavanja modela i mogućnosti da dokaz prođe u razumnom vremenu.u.

Ulazna sekvenca se generiše Python fajlom, a kao izlaz se dobija .svh fajl sa informacijama potrebnim za checker. Za željeni broj diskova potrebno je generisati odgovarajući fajl, uključiti ga u checker i pokrenuti dokaz. Skripta se pokreće naredbom:

```
python3 gen_panex_svh.py --s 4 --stride 16 --out panex_s4_oracle.svh
```

Za druge vrijednosti S mijenjaju se samo broj diskova i naziv izlaznog fajla. Zbog broja stanja i dužine optimalne sekvence, za veće vrijednosti S generisanje fajla traje duže. Na Git-u sam ostavila već generisane oracle fajlove za S=3,4,5, spremne za testiranje.

Minimalan broj poteza za različite vrijednosti S je:
1:  panex_goal_bound = 3;
2:  panex_goal_bound = 13;
3:  panex_goal_bound = 42;
4:  panex_goal_bound = 128;
5:  panex_goal_bound = 343;
6:  panex_goal_bound = 881;
7:  panex_goal_bound = 2189;
8:  panex_goal_bound = 5359;
9:  panex_goal_bound = 13023;
10: panex_goal_bound = 31537;

