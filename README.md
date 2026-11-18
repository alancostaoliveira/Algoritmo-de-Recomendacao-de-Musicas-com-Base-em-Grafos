# Music Graph: recomendação musical com Neo4j

Projeto de estudo de um motor de recomendação musical baseado em grafo. A solução combina filtragem colaborativa, recomendação por conteúdo e recomendações sociais com dados de usuários, músicas, artistas e gêneros no Neo4j.

## Contexto e justificativa

Um sistema de música precisa navegar por relações como:

> "Quais músicas são preferidas por usuários que ouviram `Bohemian Rhapsody`, vivem na mesma cidade e têm idade semelhante?"

Em um banco relacional, essa resposta costuma exigir junções entre usuários, histórico de reprodução, músicas, artistas, gêneros e tabelas de relacionamento social, além de subconsultas e filtros de exclusão. Conforme o histórico cresce, os JOINs se tornam caros e difíceis de manter.

No Neo4j, as relações são cidadãos de primeira classe. Uma recomendação pode partir do usuário e percorrer diretamente os caminhos:

```text
(User)-[:LISTENED_TO]->(Music)<-[:LISTENED_TO]-(User)-[:LISTENED_TO]->(Music)
```

O Neo4j usa adjacência livre de índices; a busca tende a depender do subgrafo visitado, não da varredura de todas as linhas da base. Isso permite navegação natural por usuários, preferências e metadados musicais.

## Modelo do grafo

### Nós

| Nó | Propriedades |
| --- | --- |
| `(:User)` | `userId`, `nome`, `idade`, `cidade` |
| `(:Music)` | `trackId`, `titulo`, `popularidade` |
| `(:Artist)` | `nome` |
| `(:Genre)` | `nome` |

### Relacionamentos

| Relacionamento | Propósito |
| --- | --- |
| `(:User)-[:LISTENED_TO {playCount, rating}]->(:Music)` | Histórico e interação do usuário |
| `(:Music)-[:PERFORMED_BY]->(:Artist)` | Associação da faixa ao artista |
| `(:Music)-[:IN_GENRE]->(:Genre)` | Classificação por gênero |
| `(:User)-[:FOLLOWS]->(:User)` | Rede social |
| `(:User)-[:LIKES]->(:Artist)` | Preferência explícita para casos de cold start |

```text
(User)-[:FOLLOWS]->(User)
    |
    +--[:LISTENED_TO {playCount, rating}]--> (Music)
                                              |
                                              +--[:PERFORMED_BY]--> (Artist)
                                              |
                                              +--[:IN_GENRE]--> (Genre)

(User)-[:LIKES]->(Artist)
```

Para visualizar o modelo real conectado ao Neo4j, execute:

```cypher
CALL db.schema.visualization();
```

## Preparação e carga dos dados

O script [`load_music.cypher`](load_music.cypher) cria as restrições e carrega uma amostra executável com 5 usuários, 9 músicas, 5 artistas, 4 gêneros e suas relações. Ele usa `MERGE`, portanto pode ser reexecutado sem duplicar entidades ou relações.

1. Abra o Neo4j Browser, Aura Console ou Data Importer.
2. Execute as consultas de restrição separadamente.
3. Execute o restante de [`load_music.cypher`](load_music.cypher).

As restrições utilizadas são:

```cypher
CREATE CONSTRAINT user_id IF NOT EXISTS
FOR (u:User) REQUIRE u.userId IS UNIQUE;

CREATE CONSTRAINT music_id IF NOT EXISTS
FOR (m:Music) REQUIRE m.trackId IS UNIQUE;

CREATE CONSTRAINT artist_name IF NOT EXISTS
FOR (a:Artist) REQUIRE a.nome IS UNIQUE;

CREATE CONSTRAINT genre_name IF NOT EXISTS
FOR (g:Genre) REQUIRE g.nome IS UNIQUE;
```

Para carregar os dados a partir de arquivos CSV no Neo4j Desktop, mantenha os arquivos em `import/` e use `file:///nome-do-arquivo.csv`. Em Neo4j Aura, use URLs HTTPS acessíveis publicamente, como `https://raw.githubusercontent.com/alancostaoliveira/Algoritmo-de-Recomendacao-de-Musicas-com-Base-em-Grafos/main/dados.csv`; `file:///` não é suportado pelo Aura.

Exemplo seguro de carga CSV:

```cypher
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/alancostaoliveira/Algoritmo-de-Recomendacao-de-Musicas-com-Base-em-Grafos/main/users_sample.csv' AS row
MERGE (u:User {userId: row.user_id})
SET u.nome = row.name,
    u.idade = toInteger(row.age),
    u.cidade = row.city;
```

Para grandes volumes, prefira lotes com `CALL { ... } IN TRANSACTIONS` ou `apoc.periodic.iterate` em vez de carregar todo o CSV em uma única transação.

## Perguntas de negócio e resultados

Os resultados abaixo são provenientes da amostra incluída no script.

### 1. Filtragem colaborativa

**Pergunta:** quem ouviu `Bohemian Rhapsody` também ouviu quais músicas?

```cypher
MATCH (m:Music {titulo: 'Bohemian Rhapsody'})<-[:LISTENED_TO]-(outro:User)-[:LISTENED_TO]->(rec:Music)
WHERE rec <> m
RETURN rec.titulo AS recomendacao,
       count(DISTINCT outro) AS forca
ORDER BY forca DESC, recomendacao ASC
LIMIT 5;
```

| Recomendação | Força |
| --- | ---: |
| Don't Stop Me Now | 2 |
| Space Oddity | 2 |
| Get Lucky | 1 |
| Heroes | 1 |
| Levitating | 1 |

**Diagnóstico:** `Don't Stop Me Now` e `Space Oddity` têm a maior força nesta amostra por serem ouvidas por dois usuários que também ouviram a faixa consultada.

### 2. Recomendação por conteúdo

**Pergunta:** para Alice (`user_1`), quais músicas inéditas pertencem aos gêneros que ela mais escuta?

```cypher
MATCH (u:User {userId: 'user_1'})-[:LISTENED_TO]->(:Music)-[:IN_GENRE]->(g:Genre)
WITH u, g, count(*) AS frequencia
ORDER BY frequencia DESC
LIMIT 2
MATCH (rec:Music)-[:IN_GENRE]->(g)
WHERE NOT (u)-[:LISTENED_TO]->(rec)
RETURN g.nome AS genero, rec.titulo AS sugestao
ORDER BY genero ASC, sugestao ASC;
```

| Gênero | Sugestão |
| --- | --- |
| Pop | Don't Start Now |
| Rock | Space Oddity |

**Diagnóstico:** esta consulta oferece cold-start por item e continua útil mesmo quando não existem usuários com perfil suficientemente semelhante.

### 3. Recomendação social

**Pergunta:** o que os usuários seguidos por Alice estão ouvindo e Alice ainda não ouviu?

```cypher
MATCH (u:User {userId: 'user_1'})-[:FOLLOWS]->(amigo:User)-[:LISTENED_TO]->(m:Music)
WHERE NOT (u)-[:LISTENED_TO]->(m)
RETURN amigo.nome AS amigo,
       m.titulo AS musica,
       m.popularidade AS popularidade
ORDER BY popularidade DESC;
```

| Amigo | Música | Popularidade |
| --- | --- | ---: |
| Bob | Get Lucky | 90 |
| Bob | Space Oddity | 85 |

### Visualização

```cypher
MATCH path = (u:User)-[:LISTENED_TO]->(m:Music)-[:PERFORMED_BY]->(a:Artist)
RETURN path
LIMIT 12;
```

A consulta acima permite visualizar os caminhos `User -> LISTENED_TO -> Music -> PERFORMED_BY -> Artist` no Neo4j Browser ou no Neo4j Bloom. Por não estar disponível neste ambiente, não é incluída uma captura de tela automática.

## Similaridade de Jaccard em Cypher puro

Sem o plugin Graph Data Science, é possível comparar os artistas associados às faixas ouvidas por pares de usuários:

```cypher
MATCH (u1:User {userId: 'user_1'})-[:LISTENED_TO]->(:Music)-[:PERFORMED_BY]->(a1:Artist)
WITH u1, collect(DISTINCT a1) AS artistasU1
MATCH (u2:User)-[:LISTENED_TO]->(:Music)-[:PERFORMED_BY]->(a2:Artist)
WHERE u1 <> u2
WITH u1, u2, artistasU1, collect(DISTINCT a2) AS artistasU2
WITH u1, u2,
     [x IN artistasU1 WHERE x IN artistasU2] AS intersecao,
     artistasU1 + [x IN artistasU2 WHERE NOT x IN artistasU1] AS uniao
WITH u2.nome AS usuario,
     toFloat(size(intersecao)) / toFloat(size(uniao)) AS indiceJaccard
WHERE indiceJaccard > 0.0
RETURN usuario, indiceJaccard
ORDER BY indiceJaccard DESC
LIMIT 5;
```

## Graph Data Science

Em instâncias com o GDS instalado, os próximos passos naturais são:

- projeção de similaridade com `gds.nodeSimilarity`;
- detecção de comunidades com `gds.louvain`;
- combinação de embeddings e modelos de recomendação.

## Troubleshooting

### Dados duplicados após recarregar o script

**Problema:** usuários, músicas ou relações aparecem repetidos.

**Causa:** uso de `CREATE` em vez de `MERGE`, ou ausência das restrições.

**Solução:** executar as restrições antes da carga e usar `MERGE` nas entidades e relações. O script deste projeto é reexecutável.

### Carregamento lento ou aumento excessivo de memória

**Problema:** `LOAD CSV` em uma base grande trava ou consome muita memória.

**Solução:** criar índices/restrições antes da carga, validar o CSV e dividir o processamento com lotes ou `CALL { ... } IN TRANSACTIONS`.

### Resultados repetidos ou pouco relevantes

**Problema:** a recomendação retorna faixas já ouvidas, itens irrelevantes ou duplicatas.

**Solução:** excluir relações existentes em `WHERE NOT (u)-[:LISTENED_TO]->(rec)`, usar `count(DISTINCT outro)` e exigir uma força mínima para itens com poucos usuários em comum.

### Erro de `file:///` no Aura

**Problema:** o script local não encontra arquivos quando executado no Aura.  
**Solução:** hospedar o CSV em HTTPS e usar `LOAD CSV FROM 'https://...'` ou importar visualmente com o Data Importer.

## Estrutura do repositório

```text
README.md
load_music.cypher
```

## Referências

- [Neo4j Graph Data Science](https://neo4j.com/docs/graph-data-science/current/)
- [Neo4j Cypher Manual](https://neo4j.com/docs/cypher-manual/current/)
- [Neo4j Recommendations — graph examples](https://github.com/neo4j-graph-examples/recommendations)
- [Neo4j AuraDB](https://neo4j.com/docs/aura/)
