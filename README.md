# Music Graph: recomendacao musical com Neo4j

Este projeto demonstra um motor de recomendacao musical baseado em grafos. Ele combina filtragem colaborativa item-a-item, recomendacao por genero e recomendacao social.

## Por que grafos?

Em SQL, uma recomendacao costuma exigir joins entre usuarios, historicos, faixas, artistas, generos e relacionamentos sociais. Em uma base grande, esse custo cresce rapidamente com o historico de interacoes.

No Neo4j, os relacionamentos sao percorridos diretamente a partir dos nós. Consultas como `(:User)-[:LISTENED_TO]->(:Music)<-[:LISTENED_TO]-(:User)-[:LISTENED_TO]->(:Music)` exploram apenas o subgrafo relevante.

## Modelo de dados

**Nós**

- `(:User {userId, nome, idade, cidade})`
- `(:Music {trackId, titulo, popularidade})`
- `(:Artist {nome})`
- `(:Genre {nome})`

**Relacionamentos**

- `(:User)-[:LISTENED_TO {playCount, rating}]->(:Music)`
- `(:Music)-[:PERFORMED_BY]->(:Artist)`
- `(:Music)-[:IN_GENRE]->(:Genre)`
- `(:User)-[:FOLLOWS]->(:User)`
- `(:User)-[:LIKES]->(:Artist)`

O esquema real pode ser visualizado no Neo4j Browser com:

```cypher
CALL db.schema.visualization();
```

## Estrutura

```text
.
├── README.md
└── cypher/
    ├── constraints-artist.cypher
    ├── constraints-genre.cypher
    ├── constraints-music.cypher
    ├── constraints-user.cypher
    ├── load_music.cypher
    └── queries.cypher
```

## Como executar no Neo4j Aura ou no Browser

1. Abra o Neo4j Aura Console ou o Neo4j Browser e conecte-se ao banco.
2. Execute os quatro arquivos `cypher/constraints-*.cypher`.
3. Execute o arquivo `cypher/load_music.cypher`.
4. Execute os blocos de `cypher/queries.cypher` separadamente.

`LOAD CSV` com `file:///` funciona localmente, mas nao no Neo4j Aura. Para dados hospedados remotamente, use uma URL HTTPS publica:

```cypher
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/alancostaoliveira/Algoritmo-de-Recomendacao-de-Musicas-com-Base-em-Grafos/main/data/users.csv' AS row
MERGE (u:User {userId: row.userId})
SET u.nome = row.nome,
    u.idade = toInteger(row.idade),
    u.cidade = row.cidade;
```

Os scripts inclusos usam dados de amostra diretamente em Cypher, por isso nao dependem de acesso externo ou de arquivos locais.

## Dados de amostra

A carga cria:

- 5 usuarios
- 9 musicas
- 5 artistas
- 4 generos
- 17 interacoes `LISTENED_TO`
- relacionamentos sociais `FOLLOWS`
- preferencias diretas `LIKES`

Executar o script mais de uma vez e seguro: os nós e relacionamentos usam `MERGE` e os atributos sao atualizados com `SET`.

## Perguntas de negocio

### 1. Filtro colaborativo

```cypher
MATCH (m:Music {titulo: 'Bohemian Rhapsody'})<-[:LISTENED_TO]-(outroUser:User)-[:LISTENED_TO]->(rec:Music)
WHERE rec <> m
RETURN rec.titulo AS Recomendacao, count(DISTINCT outroUser) AS Forca
ORDER BY Forca DESC, Recomendacao ASC
LIMIT 5;
```

Resultados esperados da amostra:

| Recomendacao | Forca |
|---|---:|
| Don't Stop Me Now | 2 |
| Space Oddity | 2 |
| Get Lucky | 1 |
| Heroes | 1 |
| Levitating | 1 |

### 2. Recomendacao baseada em conteudo

```cypher
MATCH (u:User {userId: 'user_1'})-[:LISTENED_TO]->(:Music)-[:IN_GENRE]->(g:Genre)
WITH u, g, count(*) AS frequencia
ORDER BY frequencia DESC
LIMIT 2
MATCH (rec:Music)-[:IN_GENRE]->(g)
WHERE NOT (u)-[:LISTENED_TO]->(rec)
RETURN g.nome AS Genero, rec.titulo AS Sugestao
ORDER BY Genero ASC, Sugestao ASC;
```

Resultados esperados para Alice:

| Genero | Sugestao |
|---|---|
| Pop | Don't Start Now |
| Rock | Space Oddity |

### 3. Recomendacao social

```cypher
MATCH (u:User {userId: 'user_1'})-[:FOLLOWS]->(amigo:User)-[:LISTENED_TO]->(m:Music)
WHERE NOT (u)-[:LISTENED_TO]->(m)
RETURN amigo.nome AS Amigo, m.titulo AS Musica, m.popularidade AS Popularidade
ORDER BY Popularidade DESC;
```

Resultados esperados:

| Amigo | Musica | Popularidade |
|---|---|---:|
| Bob | Get Lucky | 90 |
| Bob | Space Oddity | 85 |

### 4. Similaridade de Jaccard

Exemplo em Cypher puro, sem depender da biblioteca Graph Data Science:

```cypher
MATCH (u1:User {userId: 'user_1'})-[:LISTENED_TO]->(:Music)-[:PERFORMED_BY]->(a:Artist)
WITH u1, collect(DISTINCT a) AS artistasU1
MATCH (u2:User)-[:LISTENED_TO]->(:Music)-[:PERFORMED_BY]->(a:Artist)
WHERE u1 <> u2
WITH u1, u2, artistasU1, collect(DISTINCT a) AS artistasU2
WITH u2.nome AS Usuario,
     [x IN artistasU1 WHERE x IN artistasU2] AS intersecao,
     artistasU1 + [x IN artistasU2 WHERE NOT x IN artistasU1] AS uniao
WITH Usuario,
     toFloat(size(intersecao)) / toFloat(size(uniao)) AS jaccardIndex
WHERE jaccardIndex > 0
RETURN Usuario, jaccardIndex
ORDER BY jaccardIndex DESC
LIMIT 5;
```

## Troubleshooting

- **Erro "Esperava-se exatamente uma instrucao por consulta"**: execute apenas um bloco sem comentarios e clausulas `;` separadores por vez no Neo4j Browser.
- **`file:///` nao funciona no Aura**: hospede os CSVs em uma URL HTTPS ou use a ferramenta Data Importer do Aura.
- **Resultados duplicados**: use `count(DISTINCT ...)` e `WITH DISTINCT` nos caminhos que podem visitar o mesmo nó por mais de uma rota.
- **Script aplicado duas vezes**: o uso combinado de constraints, `MERGE` e `SET` evita criar entidades ou relacoes duplicadas.
- **Relacao existente com dados antigos**: `SET r.playCount = ...` e `SET r.rating = ...` atualizam as propriedades no novo carregamento.

## Referencias

- [Neo4j Graph Database](https://neo4j.com/docs/)
- [Neo4j Cypher Manual](https://neo4j.com/docs/cypher-manual/current/)
- [Neo4j recommendation example](https://github.com/neo4j-graph-examples/recommendations)
