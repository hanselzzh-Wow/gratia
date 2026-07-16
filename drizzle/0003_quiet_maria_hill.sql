CREATE TABLE `rate_limits` (
	`fingerprint` text NOT NULL,
	`action` text NOT NULL,
	`window_start` integer NOT NULL,
	`count` integer DEFAULT 1 NOT NULL,
	`updated_at` integer NOT NULL,
	PRIMARY KEY(`fingerprint`, `action`)
);
