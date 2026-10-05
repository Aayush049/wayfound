/**
 * @license
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import { HostAndPort } from '../public_types';
/**
 * Return a connectable hostname, replacing wildcard 0.0.0.0 or :: with loopback
 * addresses 127.0.0.1 / ::1 correspondingly. See below for why this is needed:
 * https://github.com/firebase/firebase-tools-ui/issues/286
 *
 * This assumes emulators are running on the same device as fallbackHost (e.g.
 * hub), which should hold if both are started from the same CLI command.
 * @private
 */
export declare function fixHostname(host: string, fallbackHost?: string): string;
/**
 * Create a URL with host, port, and path. Handles IPv6 bracketing correctly.
 * @private
 */
export declare function makeUrl(hostAndPort: HostAndPort | string, path: string): URL;
