# Descripciones en LSB por revisar

Generado por `tool/build_rag_corpus.py`. No editar a mano.

La ventana «¿Qué es?» muestra la descripción en glosas LSB solo si la traducción provisional de la Lambda requiere revisión: cada seña se apoya en una palabra de la descripción, la negación coincide, las interrogativas solo van donde se pregunta, no se explica la palabra con ella misma y hay más señas que señas por incorporar. Estas no registran aquí, pero ya se ven en LSB en la aplicación. Para arreglarlas, reescribe la descripción en `descripciones_sin_sena.json` con palabras que tengan seña y vuelve a ejecutar `python tool/rag_descripciones_lsb.py` y `python tool/build_rag_corpus.py`.

**0 descripciones.** `*` = seña por incorporar.

| Palabra | Descripción | Traducción LSB | Motivo |
|---|---|---|---|
