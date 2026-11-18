// Filtro colaborativo item-a-item
MATCH (m:Music {titulo: 'Bohemian Rhapsody'})<-[:LISTENED_TO]-(outroUser:User)-[:LISTENED_TO]->(rec:Music)
WHERE rec <> m
RETURN rec.titulo AS Recomendacao,
       count(DISTINCT outroUser) AS Forca
ORDER BY Forca DESC, Recomendacao ASC
LIMIT 5;

// Recomendacao baseada nos dois generos mais frequentes de Alice
MATCH (u:User {userId: 'user_1'})-[:LISTENED_TO]->(:Music)-[:IN_GENRE]->(g:Genre)
WITH u, g, count(*) AS frequencia
ORDER BY frequencia DESC
LIMIT 2
MATCH (rec:Music)-[:IN_GENRE]->(g)
WHERE NOT (u)-[:LISTENED_TO]->(rec)
RETURN g.nome AS Genero, rec.titulo AS Sugestao
ORDER BY Genero ASC, Sugestao ASC;

// Recomendacao social
MATCH (u:User {userId: 'user_1'})-[:FOLLOWS]->(amigo:User)-[:LISTENED_TO]->(m:Music)
WHERE NOT (u)-[:LISTENED_TO]->(m)
RETURN amigo.nome AS Amigo,
       m.titulo AS Musica,
       m.popularidade AS Popularidade
ORDER BY Popularidade DESC;

// Similaridade de Jaccard baseada em artistas
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

// Subgrafo de exemplo para visualizacao
MATCH path = (u:User)-[:LISTENED_TO]->(m:Music)-[:PERFORMED_BY]->(a:Artist)
RETURN path
LIMIT 12;
