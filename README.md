# ec-multijob
Advanced Multijob!!

# Installation

Drag ec-multijob into the server
make sure its ensured
and run this SQL:


  CREATE TABLE `player_jobs` (
    `id` int(11) NOT NULL,
    `citizenid` varchar(50) NOT NULL,
    `name` varchar(50) NOT NULL,
    `grade` int(11) NOT NULL DEFAULT 0
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
  ALTER TABLE `player_jobs`
    ADD PRIMARY KEY (`id`),
    ADD KEY `citizenid` (`citizenid`);
And you are ready to use. Have fun

Any issues or suggestions, feel free to join the discord: https://discord.gg/XpjBM53hMh
