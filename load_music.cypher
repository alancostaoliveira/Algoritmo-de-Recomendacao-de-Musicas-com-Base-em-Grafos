// Execute estas restrições antes da carga. Requer Neo4j 5 ou superior.
CREATE CONSTRAINT user_id IF NOT EXISTS
FOR (u:User) REQUIRE u.userId IS UNIQUE;

CREATE CONSTRAINT music_id IF NOT EXISTS
FOR (m:Music) REQUIRE m.trackId IS UNIQUE;

CREATE CONSTRAINT artist_name IF NOT EXISTS
FOR (a:Artist) REQUIRE a.nome IS UNIQUE;

CREATE CONSTRAINT genre_name IF NOT EXISTS
FOR (g:Genre) REQUIRE g.nome IS UNIQUE;

// Gêneros da amostra
UNWIND [
  {nome: 'Rock'},
  {nome: 'Pop'},
  {nome: 'Electronic'},
  {nome: 'Jazz'}
] AS item
MERGE (:Genre {nome: item.nome});

// Artistas da amostra
UNWIND [
  {nome: 'Queen'},
  {nome: 'David Bowie'},
  {nome: 'Daft Punk'},
  {nome: 'Dua Lipa'},
  {nome: 'Miles Davis'}
] AS item
MERGE (:Artist {nome: item.nome});

// Músicas e metadados
UNWIND [
  {trackId: 'track_1', titulo: 'Bohemian Rhapsody', popularidade: 95, artista: 'Queen', genero: 'Rock'},
  {trackId: 'track_2', titulo: "Don't Stop Me Now", popularidade: 88, artista: 'Queen', genero: 'Rock'},
  {trackId: 'track_3', titulo: 'Heroes', popularidade: 82, artista: 'David Bowie', genero: 'Rock'},
  {trackId: 'track_4', titulo: 'Space Oddity', popularidade: 85, artista: 'David Bowie', genero: 'Rock'},
  {trackId: 'track_5', titulo: 'Get Lucky', popularidade: 90, artista: 'Daft Punk', genero: 'Electronic'},
  {trackId: 'track_6', titulo: 'One More Time', popularidade: 87, artista: 'Daft Punk', genero: 'Electronic'},
  {trackId: 'track_7', titulo: 'Levitating', popularidade: 92, artista: 'Dua Lipa', genero: 'Pop'},
  {trackId: 'track_8', titulo: "Don't Start Now", popularidade: 89, artista: 'Dua Lipa', genero: 'Pop'},
  {trackId: 'track_9', titulo: 'So What', popularidade: 78, artista: 'Miles Davis', genero: 'Jazz'}
] AS item
MERGE (music:Music {trackId: item.trackId})
SET music.titulo = item.titulo,
    music.popularidade = item.popularidade
WITH music, item
MATCH (artist:Artist {nome: item.artista})
MATCH (genre:Genre {nome: item.genero})
MERGE (music)-[:PERFORMED_BY]->(artist)
MERGE (music)-[:IN_GENRE]->(genre);

// Usuários
UNWIND [
  {userId: 'user_1', nome: 'Alice', idade: 28, cidade: 'São Paulo'},
  {userId: 'user_2', nome: 'Bob', idade: 32, cidade: 'São Paulo'},
  {userId: 'user_3', nome: 'Carlos', idade: 24, cidade: 'Rio de Janeiro'},
  {userId: 'user_4', nome: 'Diana', idade: 30, cidade: 'Curitiba'},
  {userId: 'user_5', nome: 'Eduardo', idade: 29, cidade: 'São Paulo'}
] AS item
MERGE (u:User {userId: item.userId})
SET u.nome = item.nome,
    u.idade = item.idade,
    u.cidade = item.cidade;

// Histórico de reprodução
UNWIND [
  {userId: 'user_1', trackId: 'track_1', playCount: 45, rating: 5},
  {userId: 'user_1', trackId: 'track_2', playCount: 30, rating: 5},
  {userId: 'user_1', trackId: 'track_3', playCount: 20, rating: 4},
  {userId: 'user_1', trackId: 'track_7', playCount: 15, rating: 4},
  {userId: 'user_2', trackId: 'track_1', playCount: 50, rating: 5},
  {userId: 'user_2', trackId: 'track_2', playCount: 40, rating: 5},
  {userId: 'user_2', trackId: 'track_4', playCount: 35, rating: 5},
  {userId: 'user_2', trackId: 'track_5', playCount: 10, rating: 3},
  {userId: 'user_3', trackId: 'track_5', playCount: 60, rating: 5},
  {userId: 'user_3', trackId: 'track_6', playCount: 55, rating: 5},
  {userId: 'user_3', trackId: 'track_7', playCount: 25, rating: 4},
  {userId: 'user_4', trackId: 'track_1', playCount: 12, rating: 4},
  {userId: 'user_4', trackId: 'track_4', playCount: 22, rating: 4},
  {userId: 'user_4', trackId: 'track_9', playCount: 30, rating: 5},
  {userId: 'user_5', trackId: 'track_7', playCount: 35, rating: 5},
  {userId: 'user_5', trackId: 'track_8', playCount: 40, rating: 5},
  {userId: 'user_5', trackId: 'track_5', playCount: 15, rating: 4}
] AS item
MATCH (u:User {userId: item.userId})
MATCH (music:Music {trackId: item.trackId})
MERGE (u)-[r:LISTENED_TO]->(music)
SET r.playCount = item.playCount,
    r.rating = item.rating;

// Rede social
UNWIND [
  {from: 'user_1', to: 'user_2'},
  {from: 'user_2', to: 'user_1'},
  {from: 'user_3', to: 'user_5'},
  {from: 'user_4', to: 'user_1'}
] AS item
MATCH (from:User {userId: item.from})
MATCH (to:User {userId: item.to})
MERGE (from)-[:FOLLOWS]->(to);

// Preferências explícitas de artistas
UNWIND [
  {userId: 'user_1', artista: 'Queen'},
  {userId: 'user_1', artista: 'David Bowie'},
  {userId: 'user_2', artista: 'Queen'},
  {userId: 'user_3', artista: 'Daft Punk'},
  {userId: 'user_5', artista: 'Dua Lipa'}
] AS item
MATCH (u:User {userId: item.userId})
MATCH (a:Artist {nome: item.artista})
MERGE (u)-[:LIKES]->(a);
